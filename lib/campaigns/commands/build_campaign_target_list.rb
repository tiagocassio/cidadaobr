# frozen_string_literal: true

module Campaigns
  module Commands
    class BuildCampaignTargetList < ApplicationCommand
      Result = Data.define(:created_count, :skipped_count, :updated_count, :eligible_count)

      def self.preview_scope(campaign:, definition: nil)
        raw = definition || campaign.target_audience_definition
        new(campaign: campaign).send(:base_scope, definition: audience_definition(raw))
      end

      def self.remove_stale_for!(campaign:)
        definition = audience_definition(campaign.target_audience_definition)
        instance = new(campaign: campaign)
        scope = instance.send(:base_scope, definition: definition)
        instance.send(:remove_stale_targets!, scope: scope)
      end

      def self.audience_definition(raw)
        raw.to_h.stringify_keys.except("wizard_audience_saved")
      end

      def initialize(campaign:)
        @campaign = campaign
      end

      def call
        definition = self.class.audience_definition(@campaign.target_audience_definition)
        scope = base_scope(definition: definition)
        created = 0
        skipped = 0
        updated = 0
        result = nil

        write_transaction do
          remove_stale_targets!(scope: scope)
          eligible_count = scope.count

          scope.find_each do |citizen|
            household = household_for(citizen)
            target = CampaignTarget.find_or_initialize_by(
              campaign: @campaign,
              citizen: citizen
            )
            if target.persisted?
              sync_exiting = sync_existing_target!(target, household: household, citizen: citizen)
              sync_exiting ? updated += 1 : skipped += 1
              next
            end

            target.assign_attributes(
              municipality: @campaign.municipality,
              health_facility: @campaign.health_facility,
              household: household,
              status: "pending",
              priority_score: priority_for(citizen)
            )
            target.save!
            created += 1
          end

          if @campaign.respond_to?(:status)
            @campaign.update!(status: next_status_after_build(@campaign))
          end

          result = Result.new(created_count: created, skipped_count: skipped, updated_count: updated, eligible_count: eligible_count)
          emit_targets_built!(result: result)
        end

        result
      end

      private

      def base_scope(definition:)
        scope = citizens_for_campaign(@campaign)

        if definition["care_team_ids"].present?
          scope = scope.where(care_team_id: definition["care_team_ids"])
        end

        if definition["min_age"].present? && definition["min_age"].to_i.positive?
          scope = scope.where("birth_date <= ?", Date.current - definition["min_age"].to_i.years)
        end

        if definition["max_age"].present? && definition["max_age"].to_i.positive?
          scope = scope.where("birth_date >= ?", Date.current - definition["max_age"].to_i.years)
        end

        if definition["sex"].present?
          scope = scope.where(sex: definition["sex"])
        end

        if definition["micro_area_codes"].present?
          scope = scope_for_micro_area_codes(scope, codes: definition["micro_area_codes"])
        end

        scope
      end

      def scope_for_micro_area_codes(scope, codes:)
        codes = Array(codes).compact_blank
        return scope if codes.empty?

        scope.where(
          id: HouseholdMember
                .joins(:household)
                .where(
                  households: {
                    municipality_id: @campaign.municipality_id,
                    micro_area_code: codes
                  }
                )
                .select(:citizen_id)
        )
      end

      def citizens_for_campaign(campaign)
        scope = Citizen.where(municipality_id: campaign.municipality_id)
        facility_id = campaign.health_facility_id
        return scope if facility_id.blank?

        team_ids = CareTeam.where(municipality_id: campaign.municipality_id, health_facility_id: facility_id).select(:id)
        scope.where(health_facility_id: facility_id).or(scope.where(care_team_id: team_ids))
      end

      def household_for(citizen)
        citizen.household_members.order(:created_at).first&.household
      end

      def sync_existing_target!(target, household:, citizen:)
        return false unless target.status == "pending"

        attrs = {
          household: household,
          priority_score: priority_for(citizen)
        }
        return false if target.household_id == household&.id && target.priority_score == attrs[:priority_score]

        target.update!(attrs)
        true
      end

      def remove_stale_targets!(scope:)
        statuses = stale_target_statuses(@campaign)
        CampaignTarget
          .where(campaign: @campaign, status: statuses)
          .where.not(citizen_id: scope.select(:id))
          .delete_all
      end

      def stale_target_statuses(campaign)
        return %w[pending] unless campaign.is_a?(HomeVisitCampaign)
        return %w[pending] if campaign.visit_routes.exists?

        %w[pending routed]
      end

      def priority_for(citizen)
        age = citizen.birth_date ? ((Date.current - citizen.birth_date).to_i / 365.25).floor : 0
        age >= 60 ? 100 : age
      end

      def next_status_after_build(campaign)
        case campaign
        when VaccinationCampaign
          campaign.supply_provisioning&.status == "approved" ? "scheduled" : campaign.status
        when HomeVisitCampaign
          "targets_built"
        else
          campaign.status
        end
      end

      def emit_targets_built!(result:)
        RecordPlatformEvent.call(
          event_type: Cidadaobr::KafkaTopics::CAMPAIGN_TARGETS_BUILT,
          aggregate_type: @campaign.class.name,
          aggregate_id: @campaign.id,
          payload: {
            campaign_id: @campaign.id,
            campaign_type: @campaign.class.name,
            created_count: result.created_count,
            skipped_count: result.skipped_count,
            eligible_count: result.eligible_count,
            target_count: @campaign.campaign_targets.count
          },
        )
      end
    end
  end
end
