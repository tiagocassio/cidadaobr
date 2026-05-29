# frozen_string_literal: true

module Web
  module Campaigns
    class HomeVisitCampaignsController < BaseController
      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[new create build_targets generate_routes]
      before_action :set_form_collections, only: %i[new create]
      before_action :set_campaign, only: %i[show build_targets generate_routes preview_provisioning]

      def index
        @pagy, @campaigns = pagy(
          scoped_campaigns.includes(:health_facility).order(starts_on: :desc)
        )
      end

      def show
        @targets_count = @campaign.campaign_targets.count
        @routes = @campaign.visit_routes.includes(:care_team).order(:route_date, :sequence_number)
        @provisioning = @campaign.home_visit_campaign_provisioning
      end

      def new
        @campaign = scoped_campaigns.build(
          starts_on: Date.current,
          ends_on: 30.days.from_now.to_date,
          target_audience_definition: { "min_age" => 60 },
          supply_plan: [ { "name" => "Kit visita", "supply_item_code" => "VISIT_KIT", "quantity_per_visit" => 1, "unit" => "kit" } ]
        )
      end

      def create
        @campaign = scoped_campaigns.build(campaign_params)
        @campaign.municipality = current_municipality
        @campaign.status = "draft"

        if @campaign.save
          redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                      notice: t("cidadaobr.campaigns.home_visit.flash.created")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def build_targets
        result = Campaigns::Commands::BuildCampaignTargetList.call(campaign: @campaign)
        redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                    notice: t("cidadaobr.campaigns.flash.targets_built", count: result.created_count)
      end

      def generate_routes
        result = Routing::Commands::GenerateVisitRoutes.call(
          campaign: @campaign,
          route_date: params.fetch(:route_date, Date.current)
        )
        redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                    notice: t("cidadaobr.campaigns.home_visit.flash.routes_generated", routes: result.routes_created, stops: result.stops_created)
      end

      def preview_provisioning
        @lines = Inventory::PreviewCampaignProvisioning.preview(campaign: @campaign)
        @rollup = Inventory::PreviewCampaignProvisioning.rollup!(campaign: @campaign)
      end

      private

      def scoped_campaigns
        scope = HomeVisitCampaign.where(municipality_id: current_municipality.id)
        return scope if municipality_scope?

        scope.where(health_facility_id: scoped_health_facilities.select(:id))
      end

      def set_campaign
        @campaign = scoped_campaigns.find(params[:id])
      end

      def set_form_collections
        @facilities = scoped_health_facilities.order(:name)
      end

      def campaign_params
        params.require(:home_visit_campaign).permit(
          :name,
          :health_facility_id,
          :starts_on,
          :ends_on,
          :waste_factor,
          target_audience_definition: {},
          supply_plan: [ %i[name supply_item_code quantity_per_visit unit] ]
        )
      end
    end
  end
end
