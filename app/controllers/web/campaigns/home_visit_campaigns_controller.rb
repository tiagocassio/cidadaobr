# frozen_string_literal: true

module Web
  module Campaigns
    class HomeVisitCampaignsController < BaseController
      include BuildTargetsRedirect
      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[
        new create build_targets generate_routes clear_routes publish_routes
        calculate_provisioning reserve_provisioning update_provisioning dispatch_supplies
      ]
      before_action :set_form_collections, only: %i[new create]
      before_action :set_campaign, only: %i[
        show build_targets generate_routes clear_routes publish_routes preview_provisioning
        calculate_provisioning reserve_provisioning update_provisioning dispatch_supplies route_map
      ]

      def index
        @pagy, @campaigns = pagy(
          scoped_campaigns.includes(:health_facility).order(starts_on: :desc)
        )
      end

      def show
        @targets_count = @campaign.campaign_targets.count
        @routes = @campaign.visit_routes.includes(:care_team, :visit_route_provisioning).order(:route_date, :sequence_number)
        @provisioning = @campaign.home_visit_campaign_provisioning
        @route_date, @route_date_invalid = parse_route_date_with_validation
        flash.now[:alert] = t("cidadaobr.campaigns.home_visit.flash.invalid_route_date") if @route_date_invalid
        @route_dates = @campaign.visit_routes.distinct.order(:route_date).pluck(:route_date)
        @routes_for_date = @routes.select { |route| route.route_date == @route_date }
        @team_progress = ::Campaigns::VisitRouteProgress.by_team(campaign: @campaign, route_date: @route_date)
        @campaign_progress = ::Campaigns::VisitRouteProgress.for_campaign(campaign: @campaign, route_date: @route_date)
        @phase5_ready = phase5_gate_ready?
        @provisioning_reserve_needed = provisioning_reserve_needed?
      end

      def new
        @campaign = scoped_campaigns.build(
          starts_on: Date.current,
          ends_on: 30.days.from_now.to_date,
          target_audience_definition: { "min_age" => 60 },
          supply_plan: default_supply_plan
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

        result = CommandBus.dispatch(
          ::Campaigns::Commands::CreateHomeVisitCampaign,
          campaign: @campaign,
          municipality: current_municipality
        )
        if result.success
          redirect_to web_campaigns_home_visit_campaign_path(result.campaign),
                      notice: t("cidadaobr.campaigns.home_visit.flash.created")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def build_targets
        result = CommandBus.dispatch(::Campaigns::Commands::BuildCampaignTargetList, campaign: @campaign)
        redirect_after_build_targets!(result, web_campaigns_home_visit_campaign_path(@campaign))
      end

      def generate_routes
        route_date, invalid = parse_route_date_with_validation
        if invalid
          redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                      alert: t("cidadaobr.campaigns.home_visit.flash.invalid_route_date")
          return
        end

        result = CommandBus.dispatch(
          Routing::Commands::GenerateVisitRoutes,
          campaign: @campaign,
          route_date: route_date,
          regenerate: ActiveModel::Type::Boolean.new.cast(params[:regenerate])
        )
        if result.skipped
          redirect_to web_campaigns_home_visit_campaign_path(@campaign), alert: result.message
          return
        end
        if result.routes_created.zero?
          alert = result.message
          if alert.blank? && result.unassigned_count.positive?
            alert = t("cidadaobr.campaigns.home_visit.flash.unassigned_targets", count: result.unassigned_count)
          end
          if alert.present?
            redirect_to web_campaigns_home_visit_campaign_path(@campaign), alert: alert
            return
          end
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

        result = CommandBus.dispatch(Routing::Commands::ClearVisitRoutes, campaign: @campaign, route_date: route_date)
        if result.message.present?
          redirect_to web_campaigns_home_visit_campaign_path(@campaign, route_date: route_date.iso8601),
                      alert: result.message
          return
        end

        redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                    notice: t(
                      "cidadaobr.campaigns.home_visit.flash.routes_cleared",
                      count: result.routes_removed
                    )
      end

      def publish_routes
        route_date, invalid = parse_route_date_with_validation
        if invalid
          redirect_to web_campaigns_home_visit_campaign_path(@campaign, route_date: route_date.iso8601),
                      alert: t("cidadaobr.campaigns.home_visit.flash.invalid_route_date")
          return
        end

        result = CommandBus.dispatch(
          Routing::Commands::PublishVisitRoutes,
          campaign: @campaign,
          route_date: route_date
        )
        if result.message.present?
          redirect_to web_campaigns_home_visit_campaign_path(@campaign, route_date: route_date.iso8601),
                      alert: result.message
          return
        end

        @campaign.reload
        notice = t(
          "cidadaobr.campaigns.home_visit.flash.routes_published",
          count: result.routes_published
        )
        if result.routes_published.positive? && @campaign.visit_routes.where(status: "draft").exists?
          notice = "#{notice} #{t('cidadaobr.campaigns.home_visit.flash.routes_published_other_dates_pending')}"
        end

        redirect_to web_campaigns_home_visit_campaign_path(@campaign, route_date: route_date.iso8601),
                    notice: notice
      end

      def preview_provisioning
        @route_date, @route_date_invalid = parse_route_date_with_validation
        flash.now[:alert] = t("cidadaobr.campaigns.home_visit.flash.invalid_route_date") if @route_date_invalid
        @route_dates = @campaign.visit_routes.distinct.order(:route_date).pluck(:route_date)
        @lines = Inventory::PreviewCampaignProvisioning.preview(campaign: @campaign)
        @rollup = preview_provisioning_rollup
      end

      def calculate_provisioning
        route_date, invalid = parse_route_date_with_validation
        if invalid
          redirect_to preview_provisioning_web_campaigns_home_visit_campaign_path(@campaign),
                      alert: t("cidadaobr.campaigns.home_visit.flash.invalid_route_date")
          return
        end

        Inventory::PreviewCampaignProvisioning.rollup!(
          campaign: @campaign,
          route_date: rollup_route_date(route_date)
        )
        redirect_to preview_provisioning_web_campaigns_home_visit_campaign_path(
          @campaign,
          route_date: route_date.iso8601
        ),
                    notice: t("cidadaobr.campaigns.home_visit.flash.provisioning_calculated")
      end

      def reserve_provisioning
        route_date, invalid = reserve_scope_route_date
        if invalid
          redirect_after_reserve_provisioning(alert: t("cidadaobr.campaigns.home_visit.flash.invalid_route_date"))
          return
        end

        result = CommandBus.dispatch(
          Inventory::Commands::ReserveVisitRouteSupplies,
          campaign: @campaign,
          route_date: route_date
        )
        if result.blocked
          redirect_after_reserve_provisioning(alert: result.message)
          return
        end

        redirect_after_reserve_provisioning(
          notice: t(
            "cidadaobr.campaigns.home_visit.flash.provisioning_reserved",
            count: result.routes_reserved
          )
        )
      end

      def update_provisioning
        route_date, invalid = parse_route_date_with_validation
        if invalid
          redirect_to preview_provisioning_web_campaigns_home_visit_campaign_path(@campaign),
                      alert: t("cidadaobr.campaigns.home_visit.flash.invalid_route_date")
          return
        end

        totals = params.require(:totals).map do |line|
          line.permit(:key, :label, :quantity_required, :unit, :supply_item_id, :immunobiological_product_id).to_h
        end
        CommandBus.dispatch(
          Inventory::Commands::UpdateCampaignProvisioning,
          campaign: @campaign,
          totals: totals,
          route_date: route_date
        )
        redirect_to preview_provisioning_web_campaigns_home_visit_campaign_path(
          @campaign,
          route_date: route_date.iso8601
        ),
                    notice: t("cidadaobr.campaigns.home_visit.flash.provisioning_updated")
      rescue ArgumentError
        redirect_to preview_provisioning_web_campaigns_home_visit_campaign_path(
          @campaign,
          route_date: route_date.iso8601
        ),
                    alert: t("cidadaobr.campaigns.home_visit.flash.provisioning_update_failed")
      end

      def dispatch_supplies
        route_date, invalid = parse_route_date_with_validation
        if invalid
          redirect_to web_campaigns_home_visit_campaign_path(@campaign),
                      alert: t("cidadaobr.campaigns.home_visit.flash.invalid_route_date")
          return
        end

        care_team = scoped_care_teams.find_by(id: params.require(:care_team_id))
        unless care_team && @campaign.visit_routes.exists?(route_date: route_date, care_team_id: care_team.id)
          redirect_to web_campaigns_home_visit_campaign_path(@campaign, route_date: route_date.iso8601),
                      alert: t("cidadaobr.campaigns.home_visit.flash.invalid_care_team")
          return
        end

        result = CommandBus.dispatch(
          Inventory::Commands::DispatchTeamSupplyKit,
          campaign: @campaign,
          care_team: care_team,
          dispatch_date: route_date
        )
        if result.message.present?
          redirect_to web_campaigns_home_visit_campaign_path(@campaign, route_date: route_date.iso8601),
                      alert: result.message
          return
        end

        redirect_to web_campaigns_home_visit_campaign_path(@campaign, route_date: route_date.iso8601),
                    notice: t("cidadaobr.campaigns.home_visit.flash.supplies_dispatched")
      end

      def route_map
        route_date, @route_date_invalid = parse_route_date_with_validation
        @routes = @campaign.visit_routes
          .where(route_date: route_date)
          .includes(:care_team, visit_route_stops: { citizen: { households: [] }, household: [] })
          .order(:sequence_number)
        @map_markers = []
        @route_map_payload = @routes.filter_map do |route|
          stops = route.visit_route_stops.sort_by(&:stop_order).filter_map do |stop|
            household = stop.household || stop.citizen.household_members.order(:created_at).first&.household
            next unless household&.location

            marker = {
              lat: household.location.y,
              lng: household.location.x,
              label: "#{route.care_team.name} · #{stop.citizen.full_name} · parada #{stop.stop_order}",
              route_id: route.id
            }
            @map_markers << marker
            { lat: marker[:lat], lng: marker[:lng], label: marker[:label] }
          end
          next if stops.empty?

          { id: route.id, label: route.care_team.name, stops: stops }
        end
        facility = @campaign.health_facility
        if facility&.location.present?
          @depot = { lat: facility.location.y, lng: facility.location.x, label: facility.name }
        end
        @map_center = route_map_default_center(facility)
      end

      def route_map_default_center(facility)
        if facility&.location.present?
          return { lat: facility.location.y, lng: facility.location.x }
        end

        coords = HealthFacility
          .where(municipality_id: @campaign.municipality_id)
          .where.not(location: nil)
          .limit(20)
          .filter_map(&:coordinates)
        return nil if coords.empty?

        {
          lat: coords.sum { |point| point[:lat] } / coords.size,
          lng: coords.sum { |point| point[:lng] } / coords.size
        }
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

      def default_supply_plan
        visit_kit = SupplyItem.composites.find_by(municipality_id: current_municipality.id, name: "Kit visita domiciliar")
        return [] unless visit_kit

        [
          {
            "supply_item_id" => visit_kit.id,
            "quantity_per_visit" => 1,
            "unit" => visit_kit.unit
          }
        ]
      end

      def campaign_params
        permitted = params.require(:home_visit_campaign).permit(
          :name,
          :health_facility_id,
          :starts_on,
          :ends_on,
          :waste_factor,
          target_audience_definition: {},
          supply_plan: [ %i[supply_item_id quantity_per_visit unit] ]
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

      def reserve_scope_route_date
        return [ nil, false ] if ActiveModel::Type::Boolean.new.cast(params[:all_routes])

        parse_route_date_with_validation
      end

      RESERVE_RETURN_TO_ALLOWLIST = %w[show].freeze

      def redirect_after_reserve_provisioning(notice: nil, alert: nil)
        if RESERVE_RETURN_TO_ALLOWLIST.include?(params[:return_to])
          route_date, = parse_route_date_with_validation
          redirect_to web_campaigns_home_visit_campaign_path(@campaign, route_date: route_date.iso8601),
                      notice: notice,
                      alert: alert
        else
          redirect_to preview_provisioning_web_campaigns_home_visit_campaign_path(@campaign),
                      notice: notice,
                      alert: alert
        end
      end

      def preview_provisioning_rollup
        if @campaign.visit_routes.exists?
          Inventory::PreviewCampaignProvisioning.rollup_snapshot(
            campaign: @campaign,
            route_date: @route_date
          )
        else
          @campaign.home_visit_campaign_provisioning
        end
      end

      def rollup_route_date(route_date)
        return nil unless @campaign.visit_routes.exists?

        @campaign.visit_routes.exists?(route_date: route_date) ? route_date : nil
      end

      def provisioning_reserve_needed?
        @routes_for_date.any? { |route| route_needs_provisioning_reserve?(route) }
      end

      def route_needs_provisioning_reserve?(route)
        return false unless route.status.in?(%w[draft published])

        prov = route.visit_route_provisioning
        prov.blank? || !prov.status.in?(%w[reserved dispatched])
      end

      def phase5_gate_ready?
        return false unless @campaign.campaign_targets.exists?

        published_routes = @campaign.visit_routes.where(status: "published", route_date: @route_date)
        return false if published_routes.none?

        return false unless published_routes.all? do |route|
          route.visit_route_provisioning&.status.in?(%w[reserved dispatched])
        end

        published_routes.distinct.pluck(:care_team_id).all? do |team_id|
          TeamSupplyDispatch.exists?(
            municipality_id: @campaign.municipality_id,
            health_facility_id: @campaign.health_facility_id,
            care_team_id: team_id,
            dispatch_date: @route_date,
            status: "dispatched"
          )
        end
      end
    end
  end
end
