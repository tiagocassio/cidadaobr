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
          key: "immunobiological_doses",
          label: campaign.immunobiological_product.name,
          required: required_doses,
          available: doses_available.to_i,
          unit: "dose"
        )

        syringe_required = (required_doses * syringes_per_dose.to_i)
        lines = [ dose_line ]
        if supply_syringe_configured?(campaign: campaign)
          syringe_available = available_supply_at(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id,
            code_prefix: "SYRINGE",
            immunobiological_product_id: campaign.immunobiological_product_id,
            exclude_vaccination_campaign_id: campaign.id
          )
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

      def persist!(campaign:)
        Inventory::Commands::PersistVaccinationProvisioning.call(campaign: campaign)
      end

      def available_doses_for(campaign:)
        available_doses_at(
          municipality_id: campaign.municipality_id,
          health_facility_id: campaign.health_facility_id,
          immunobiological_product_id: campaign.immunobiological_product_id,
          exclude_vaccination_campaign_id: campaign.id
        )
      end

      def available_doses_at(municipality_id:, health_facility_id:, immunobiological_product_id:, exclude_vaccination_campaign_id: nil)
        on_hand = ImmunobiologicalLot
          .where(
            municipality_id: municipality_id,
            health_facility_id: health_facility_id,
            immunobiological_product_id: immunobiological_product_id
          )
          .fefo
          .not_expired
          .sum(:quantity_on_hand)
          .to_i

        committed = committed_doses_elsewhere(
          municipality_id: municipality_id,
          health_facility_id: health_facility_id,
          immunobiological_product_id: immunobiological_product_id,
          exclude_vaccination_campaign_id: exclude_vaccination_campaign_id
        )

        [ on_hand - committed, 0 ].max
      end

      def available_supply_at(municipality_id:, health_facility_id:, code_prefix:, immunobiological_product_id: nil, exclude_vaccination_campaign_id: nil, syringes_per_dose: 1)
        on_hand = supply_quantity_at(
          municipality_id: municipality_id,
          health_facility_id: health_facility_id,
          code_prefix: code_prefix
        )
        return on_hand unless code_prefix.to_s.start_with?("SYRINGE")
        return on_hand if immunobiological_product_id.blank?

        committed_syringes = committed_doses_elsewhere(
          municipality_id: municipality_id,
          health_facility_id: health_facility_id,
          immunobiological_product_id: immunobiological_product_id,
          exclude_vaccination_campaign_id: exclude_vaccination_campaign_id
        ) * syringes_per_dose.to_i

        [ on_hand - committed_syringes, 0 ].max
      end

      def lock_stock_for_facility_product!(municipality_id:, health_facility_id:, immunobiological_product_id:, exclude_vaccination_campaign_id: nil)
        ImmunobiologicalLot
          .where(
            municipality_id: municipality_id,
            health_facility_id: health_facility_id,
            immunobiological_product_id: immunobiological_product_id
          )
          .lock
          .load

        scope = VaccinationCampaign
          .where(
            municipality_id: municipality_id,
            health_facility_id: health_facility_id,
            immunobiological_product_id: immunobiological_product_id,
            status: %w[provisioning_approved scheduled active]
          )
        scope = scope.where.not(id: exclude_vaccination_campaign_id) if exclude_vaccination_campaign_id.present?
        scope.lock.load

        lock_syringe_stock!(municipality_id: municipality_id, health_facility_id: health_facility_id)
      end

      def lock_stock_for_home_visit!(campaign:)
        product_id = campaign.target_audience_definition.to_h["immunobiological_product_id"]
        if product_id.present?
          lock_stock_for_facility_product!(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id,
            immunobiological_product_id: product_id
          )
        else
          lock_syringe_stock!(
            municipality_id: campaign.municipality_id,
            health_facility_id: campaign.health_facility_id
          )
        end
      end

      def lock_syringe_stock!(municipality_id:, health_facility_id:)
        item_ids = SupplyItem
          .where(municipality_id: municipality_id)
          .where("code LIKE ?", "SYRINGE%")
          .pluck(:id)
        return if item_ids.empty?

        StockBalance
          .where(
            municipality_id: municipality_id,
            health_facility_id: health_facility_id,
            supply_item_id: item_ids
          )
          .lock
          .load
      end

      def emit_rejection_event!(campaign:, provisioning:)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::SUPPLY_PROVISIONING_REJECTED,
          aggregate_type: "SupplyProvisioning",
          aggregate_id: provisioning.id,
          payload: {
            provisionable_type: campaign.class.name,
            provisionable_id: campaign.id,
            health_facility_id: campaign.health_facility_id,
            shortages: provisioning.shortages,
            rejection_reason: provisioning.rejection_reason
          }
        )
      end

      private

      def lock_stock_for_campaign!(campaign)
        campaign.lock! if campaign.persisted?

        lock_stock_for_facility_product!(
          municipality_id: campaign.municipality_id,
          health_facility_id: campaign.health_facility_id,
          immunobiological_product_id: campaign.immunobiological_product_id,
          exclude_vaccination_campaign_id: campaign.id
        )
      end

      def supply_syringe_configured?(campaign:)
        SupplyItem.where(municipality_id: campaign.municipality_id).where("code LIKE ?", "SYRINGE%").exists?
      end

      def supply_quantity_at(municipality_id:, health_facility_id:, code_prefix:)
        item_ids = SupplyItem
          .where(municipality_id: municipality_id)
          .where("code LIKE ?", "#{code_prefix}%")
          .pluck(:id)
        return 0 if item_ids.empty?

        StockBalance
          .where(
            municipality_id: municipality_id,
            health_facility_id: health_facility_id,
            supply_item_id: item_ids
          )
          .sum(:quantity)
          .to_i
      end

      def available_supply_quantity(campaign:, code_prefix:)
        supply_quantity_at(
          municipality_id: campaign.municipality_id,
          health_facility_id: campaign.health_facility_id,
          code_prefix: code_prefix
        )
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

      def committed_doses_elsewhere(municipality_id:, health_facility_id:, immunobiological_product_id:, exclude_vaccination_campaign_id: nil)
        scope = VaccinationCampaign
          .where(
            municipality_id: municipality_id,
            health_facility_id: health_facility_id,
            immunobiological_product_id: immunobiological_product_id,
            status: %w[provisioning_approved scheduled active]
          )
        scope = scope.where.not(id: exclude_vaccination_campaign_id) if exclude_vaccination_campaign_id.present?
        scope.sum(:target_doses).to_i
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
    end
  end
end
