# frozen_string_literal: true

module Web
  module Campaigns
    class VaccinationCampaignsController < BaseController
      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[new create edit update build_targets publish]
      before_action :set_form_collections, only: %i[new create edit update]
      before_action :set_campaign, only: %i[show edit update preview_targets build_targets publish]

      def index
        @pagy, @campaigns = pagy(
          scoped_campaigns.includes(:health_facility, :immunobiologic_product).order(starts_on: :desc)
        )
      end

      def show
        @provisioning = @campaign.supply_provisioning
        @targets = @campaign.campaign_targets.includes(:citizen).order(priority_score: :desc).limit(50)
      end

      def preview_targets
        @definition = @campaign.target_audience_definition
        @preview_count = Campaigns::Commands::BuildCampaignTargetList.preview_scope(campaign: @campaign).count
      end

      def new
        @campaign = scoped_campaigns.build(
          starts_on: Date.current,
          ends_on: 7.days.from_now.to_date,
          campaign_kind: "human_immunization",
          target_audience_definition: { "min_age" => 60 }
        )
      end

      def create
        @campaign = scoped_campaigns.build(campaign_params)
        @campaign.municipality = current_municipality
        @campaign.status = "draft"

        if add_scoped_param_errors(
          @campaign,
          raw_facility_id: params.dig(:vaccination_campaign, :health_facility_id),
          raw_room_id: params.dig(:vaccination_campaign, :consultation_room_id),
          health_facility_id: sanitize_scoped_health_facility_id(params.dig(:vaccination_campaign, :health_facility_id))
        )
          render :new, status: :unprocessable_entity
          return
        end

        if @campaign.save
          run_provisioning!
          redirect_to web_campaigns_vaccination_campaign_path(@campaign),
                      notice: provisioning_notice(@last_provisioning_result)
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if add_scoped_param_errors(
          @campaign,
          raw_facility_id: params.dig(:vaccination_campaign, :health_facility_id),
          raw_room_id: params.dig(:vaccination_campaign, :consultation_room_id),
          health_facility_id: sanitize_scoped_health_facility_id(params.dig(:vaccination_campaign, :health_facility_id))
        )
          render :edit, status: :unprocessable_entity
          return
        end

        if @campaign.update(campaign_params)
          run_provisioning!
          redirect_to web_campaigns_vaccination_campaign_path(@campaign),
                      notice: t("cidadaobr.campaigns.flash.updated")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def build_targets
        result = Campaigns::Commands::BuildCampaignTargetList.call(campaign: @campaign)
        redirect_to web_campaigns_vaccination_campaign_path(@campaign),
                    notice: t("cidadaobr.campaigns.flash.targets_built", count: result.created_count)
      end

      def publish
        unless @campaign.supply_provisioning&.status == "approved"
          redirect_to web_campaigns_vaccination_campaign_path(@campaign),
                      alert: t("cidadaobr.campaigns.flash.publish_blocked")
          return
        end

        unless @campaign.campaign_targets.exists?
          redirect_to web_campaigns_vaccination_campaign_path(@campaign),
                      alert: t("cidadaobr.campaigns.flash.publish_no_targets")
          return
        end

        @campaign.update!(status: "active")
        redirect_to web_campaigns_vaccination_campaign_path(@campaign),
                    notice: t("cidadaobr.campaigns.flash.published")
      end

      private

      def scoped_campaigns
        scope = VaccinationCampaign.where(municipality_id: current_municipality.id)
        return scope if municipality_scope?

        scope.where(health_facility_id: scoped_health_facilities.select(:id))
      end

      def set_campaign
        @campaign = scoped_campaigns.find(params[:id])
      end

      def set_form_collections
        @facilities = scoped_health_facilities.order(:name)
        @products = ImmunobiologicProduct.where(municipality_id: current_municipality.id, active: true).order(:name)
        @rooms = ConsultationRoom.where(municipality_id: current_municipality.id, active: true).order(:name)
      end

      def campaign_params
        permitted = params.require(:vaccination_campaign).permit(
          :name,
          :health_facility_id,
          :immunobiologic_product_id,
          :consultation_room_id,
          :campaign_kind,
          :starts_on,
          :ends_on,
          :target_doses,
          :room_capacity_per_day,
          target_audience_definition: {}
        )
        permitted[:health_facility_id] = sanitize_scoped_health_facility_id(permitted[:health_facility_id])
        permitted[:consultation_room_id] = sanitize_scoped_consultation_room_id(
          permitted[:consultation_room_id],
          health_facility_id: permitted[:health_facility_id]
        )
        permitted
      end

      def run_provisioning!
        @last_provisioning_result = Inventory::ProvisioningValidator.persist!(campaign: @campaign)
      end

      def provisioning_notice(result)
        if result.feasible
          t("cidadaobr.campaigns.flash.created_provisioning_ok")
        else
          t("cidadaobr.campaigns.flash.created_provisioning_blocked")
        end
      end
    end
  end
end
