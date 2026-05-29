# frozen_string_literal: true

module Web
  module Campaigns
    class HomeVisitCampaignsController < BaseController
      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[new create build_targets generate_routes clear_routes publish_routes calculate_provisioning]
      before_action :set_form_collections, only: %i[new create]
      before_action :set_campaign, only: %i[show build_targets generate_routes clear_routes publish_routes preview_provisioning calculate_provisioning]

      def index
        @pagy, @campaigns = pagy(
          scoped_campaigns.includes(:health_facility).order(starts_on: :desc)
        )
      end

      def show
        @targets_count = @campaign.campaign_targets.count
        @routes = @campaign.visit_routes.includes(:care_team).order(:route_date, :sequence_number)
        @provisioning = @campaign.home_visit_campaign_provisioning
        @route_date, @route_date_invalid = parse_route_date_with_validation
        flash.now[:alert] = t("cidadaobr.campaigns.home_visit.flash.invalid_route_date") if @route_date_invalid
        @route_dates = @campaign.visit_routes.distinct.order(:route_date).pluck(:route_date)
        @routes_for_date = @routes.select { |route| route.route_date == @route_date }
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

        if add_scoped_param_errors(@campaign, raw_facility_id: params.dig(:home_visit_campaign, :health_facility_id))
          render :new, status: :unprocessable_entity
          return
        end

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
        route_date, invalid = parse_route_date_with_validation
        if invalid
          redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                      alert: t("cidadaobr.campaigns.home_visit.flash.invalid_route_date")
          return
        end

        result = Routing::Commands::GenerateVisitRoutes.call(
          campaign: @campaign,
          route_date: route_date,
          regenerate: ActiveModel::Type::Boolean.new.cast(params[:regenerate])
        )
        if result.skipped
          redirect_to web_campaigns_home_visit_campaign_path(@campaign), alert: result.message
          return
        end

        notice = t(
          "cidadaobr.campaigns.home_visit.flash.routes_generated",
          routes: result.routes_created,
          stops: result.stops_created
        )
        if result.unassigned_count.positive?
          notice = "#{notice} #{t('cidadaobr.campaigns.home_visit.flash.unassigned_targets', count: result.unassigned_count)}"
        end
        redirect_to web_campaigns_home_visit_campaign_path(@campaign), notice: notice
      end

      def clear_routes
        route_date, invalid = parse_route_date_with_validation
        if invalid
          redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                      alert: t("cidadaobr.campaigns.home_visit.flash.invalid_route_date")
          return
        end

        result = Routing::Commands::ClearVisitRoutes.call(campaign: @campaign, route_date: route_date)
        redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                    notice: t(
                      "cidadaobr.campaigns.home_visit.flash.routes_cleared",
                      count: result.routes_removed
                    )
      end

      def publish_routes
        route_date, invalid = parse_route_date_with_validation
        if invalid
          redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                      alert: t("cidadaobr.campaigns.home_visit.flash.invalid_route_date")
          return
        end

        result = Routing::Commands::PublishVisitRoutes.call(campaign: @campaign, route_date: route_date)
        if result.message.present?
          redirect_to web_campaigns_home_visit_campaign_path(@campaign), alert: result.message
          return
        end

        redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                    notice: t(
                      "cidadaobr.campaigns.home_visit.flash.routes_published",
                      count: result.routes_published
                    )
      end

      def preview_provisioning
        @lines = Inventory::PreviewCampaignProvisioning.preview(campaign: @campaign)
        @rollup = @campaign.home_visit_campaign_provisioning
      end

      def calculate_provisioning
        Inventory::PreviewCampaignProvisioning.rollup!(campaign: @campaign)
        redirect_to preview_provisioning_web_campaigns_home_visit_campaign_path(@campaign),
                    notice: t("cidadaobr.campaigns.home_visit.flash.provisioning_calculated")
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
        permitted = params.require(:home_visit_campaign).permit(
          :name,
          :health_facility_id,
          :starts_on,
          :ends_on,
          :waste_factor,
          target_audience_definition: {},
          supply_plan: [ %i[name supply_item_code quantity_per_visit unit] ]
        )
        permitted[:health_facility_id] = sanitize_scoped_health_facility_id(permitted[:health_facility_id])
        permitted
      end

      def parse_route_date_with_validation
        return [ Date.current, false ] if params[:route_date].blank?

        [ Date.iso8601(params[:route_date]), false ]
      rescue Date::Error
        [ Date.current, true ]
      end
    end
  end
end
