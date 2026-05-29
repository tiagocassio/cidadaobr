# frozen_string_literal: true

module Inventory
  class ProvisioningValidator
    Line = Data.define(:key, :label, :required, :available, :unit)
    Result = Data.define(:feasible, :capacity_ok, :lines, :shortages)

    class << self
      def call(campaign:, available_doses: nil, room_capacity_per_day: nil, syringes_per_dose: 1)
        required_doses = campaign.target_doses.to_i
        doses_available = available_doses || available_doses_for(campaign: campaign)
        capacity_ok = capacity_ok?(campaign: campaign, room_capacity_per_day: room_capacity_per_day)

        dose_line = Line.new(
          key: "immunobiologic_doses",
          label: campaign.immunobiologic_product.name,
          required: required_doses,
          available: doses_available.to_i,
          unit: "dose"
        )

        syringe_required = (required_doses * syringes_per_dose.to_i)
        lines = [ dose_line ]
        if supply_syringe_configured?(campaign: campaign)
          syringe_available = available_supply_quantity(campaign: campaign, code_prefix: "SYRINGE")
          lines << Line.new(
            key: "supply_syringes",
            label: "Seringas",
            required: syringe_required,
            available: syringe_available,
            unit: "unit"
          )
        end
        shortages = lines.flat_map { |line| build_shortages(line) }
        shortages << capacity_shortage(campaign) unless capacity_ok

        Result.new(
          feasible: shortages.empty?,
          capacity_ok: capacity_ok,
          lines: lines,
          shortages: shortages.uniq
        )
      end

      def persist!(campaign:, result:)
        campaign.supply_provisioning&.destroy

        provisioning = SupplyProvisioning.create!(
          municipality: campaign.municipality,
          health_facility: campaign.health_facility,
          provisionable: campaign,
          status: result.feasible ? "approved" : "rejected",
          required_items: result.lines.map(&:to_h),
          available_items: result.lines.map { |line| line.to_h.merge(available: line.available) },
          shortages: result.shortages,
          capacity_ok: result.capacity_ok,
          rejection_reason: result.feasible ? nil : result.shortages.join("; ")
        )

        emit_rejection_event!(campaign: campaign, provisioning: provisioning) unless result.feasible

        campaign.update!(status: result.feasible ? "provisioning_approved" : "draft")
        provisioning
      end

      def available_doses_for(campaign:)
        ImmunobiologicLot
          .where(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id,
            immunobiologic_product_id: campaign.immunobiologic_product_id
          )
          .fefo
          .not_expired
          .sum(:quantity_on_hand)
      end

      private

      def supply_syringe_configured?(campaign:)
        SupplyItem.where(municipality_id: campaign.municipality_id).where("code LIKE ?", "SYRINGE%").exists?
      end

      def available_supply_quantity(campaign:, code_prefix:)
        item_ids = SupplyItem
          .where(municipality_id: campaign.municipality_id)
          .where("code LIKE ?", "#{code_prefix}%")
          .pluck(:id)
        return 0 if item_ids.empty?

        StockBalance
          .where(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id,
            supply_item_id: item_ids
          )
          .sum(:quantity)
          .to_i
      end

      def capacity_ok?(campaign:, room_capacity_per_day:)
        required = campaign.target_doses.to_i
        return true if required.zero?

        scheduled_capacity = scheduled_room_capacity(campaign: campaign)
        per_day = room_capacity_per_day || campaign.room_capacity_per_day
        total_capacity = scheduled_capacity.positive? ? scheduled_capacity : (per_day * campaign_days(campaign))

        total_capacity >= required
      end

      def scheduled_room_capacity(campaign:)
        scope = RoomCapacitySlot
          .where(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id,
            slot_date: campaign.starts_on..campaign.ends_on
          )
        scope = scope.where(consultation_room_id: campaign.consultation_room_id) if campaign.consultation_room_id.present?
        scope.sum(:capacity).to_i
      end

      def campaign_days(campaign)
        days = (campaign.ends_on - campaign.starts_on).to_i + 1
        days.positive? ? days : 0
      end

      def build_shortages(line)
        return [] if line.available >= line.required

        [ "#{line.label}: required #{line.required}, available #{line.available}" ]
      end

      def capacity_shortage(campaign)
        scheduled = scheduled_room_capacity(campaign: campaign)
        if scheduled.positive?
          "Room capacity: required #{campaign.target_doses} doses, scheduled slot capacity #{scheduled}"
        else
          days = campaign_days(campaign)
          capacity = campaign.room_capacity_per_day * days
          "Room capacity: required #{campaign.target_doses} doses, capacity #{capacity} (#{campaign.room_capacity_per_day}/day × #{days} days)"
        end
      end

      def emit_rejection_event!(campaign:, provisioning:)
        RecordPlatformEvent.new(
          event_type: "supply.provisioning.rejected",
          aggregate_type: "SupplyProvisioning",
          aggregate_id: provisioning.id,
          topic: "supply.provisioning.rejected",
          payload: {
            provisionable_type: campaign.class.name,
            provisionable_id: campaign.id,
            health_facility_id: campaign.health_facility_id,
            shortages: provisioning.shortages,
            rejection_reason: provisioning.rejection_reason
          }
        ).call
      end
    end
  end
end
