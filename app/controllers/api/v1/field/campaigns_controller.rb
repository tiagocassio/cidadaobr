# frozen_string_literal: true

module Api
  module V1
    module Field
      class CampaignsController < Api::BaseController
        def index
          @campaigns = HomeVisitCampaign
            .where(municipality_id: current_membership.municipality_id, status: %w[scheduled active routes_generated])
            .order(starts_on: :desc)
          @campaigns = @campaigns.where(health_facility_id: current_membership.health_facility_id) if current_membership.health_facility_id.present?
        end

        def show
          @campaign = scoped_campaigns.find(params[:id])
          @targets_count = @campaign.campaign_targets.count
        end

        private

        def scoped_campaigns
          scope = HomeVisitCampaign.where(municipality_id: current_membership.municipality_id)
          return scope unless current_membership.health_facility_id

          scope.where(health_facility_id: current_membership.health_facility_id)
        end
      end
    end
  end
end
