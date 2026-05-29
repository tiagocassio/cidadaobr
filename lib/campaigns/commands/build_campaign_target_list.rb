# frozen_string_literal: true

module Campaigns
  module Commands
    class BuildCampaignTargetList
      Result = Data.define(:created_count, :skipped_count)

      class << self
        def preview_scope(campaign:)
          base_scope(
            campaign: campaign,
            definition: campaign.target_audience_definition.to_h.stringify_keys
          )
        end

        def call(campaign:)
          definition = campaign.target_audience_definition.to_h.stringify_keys
          scope = base_scope(campaign: campaign, definition: definition)
          created = 0
          skipped = 0

          scope.find_each do |citizen|
            household = household_for(citizen)
            target = CampaignTarget.find_or_initialize_by(
              campaign: campaign,
              citizen: citizen
            )
            if target.persisted?
              skipped += 1
              next
            end

            target.assign_attributes(
              municipality: campaign.municipality,
              health_facility: campaign.health_facility,
              household: household,
              status: "pending",
              priority_score: priority_for(citizen)
            )
            target.save!
            created += 1
          end

          campaign.update!(status: next_status_after_build(campaign)) if campaign.respond_to?(:status)

          Result.new(created_count: created, skipped_count: skipped)
        end

        private

        def base_scope(campaign:, definition:)
          scope = Citizen.where(municipality_id: campaign.municipality_id)
          scope = scope.where(health_facility_id: campaign.health_facility_id) if campaign.respond_to?(:health_facility_id)

          if definition["care_team_ids"].present?
            scope = scope.where(care_team_id: definition["care_team_ids"])
          end

          if definition["min_age"].present?
            scope = scope.where("birth_date <= ?", Date.current - definition["min_age"].to_i.years)
          end

          if definition["max_age"].present?
            scope = scope.where("birth_date >= ?", Date.current - definition["max_age"].to_i.years)
          end

          if definition["sex"].present?
            scope = scope.where(sex: definition["sex"])
          end

          if definition["micro_area_codes"].present?
            scope = scope.where(
              id: HouseholdMember
                .joins(:household)
                .where(households: { micro_area_code: definition["micro_area_codes"] })
                .select(:citizen_id)
            )
          end

          scope
        end

        def household_for(citizen)
          citizen.household_members.order(:created_at).first&.household
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
      end
    end
  end
end
