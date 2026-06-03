# frozen_string_literal: true

module Web
  module Campaigns
    class VaccinationCampaignsController < BaseController
      include BuildTargetsRedirect
      WIZARD_STEPS = 4
      STEP1_ATTRS = %w[
        name health_facility_id immunobiological_product_id consultation_room_id
        campaign_kind starts_on ends_on room_capacity_per_day
      ].freeze

      before_action :require_facility_or_municipality!
      before_action :require_facility_or_municipality_write!, only: %i[
        new create edit update wizard update_wizard build_targets publish
        preview_provisioning calculate_provisioning
      ]
      before_action :set_form_collections, only: %i[new create edit update wizard update_wizard]
      before_action :set_wizard_collections, only: %i[wizard update_wizard]
      before_action :set_campaign, only: %i[
        show edit update preview_targets build_targets publish wizard update_wizard
        preview_provisioning calculate_provisioning
      ]
      before_action :reject_mutations_when_active!, only: %i[update update_wizard build_targets calculate_provisioning]

      def index
        @pagy, @campaigns = pagy(
          scoped_campaigns.includes(:health_facility, :immunobiological_product).order(starts_on: :desc)
        )
      end

      def show
        @provisioning = @campaign.supply_provisioning
        @targets = @campaign.campaign_targets.includes(:citizen).order(priority_score: :desc).limit(50)
        @wizard_completion_step = wizard_completion_step
        @max_allowed_wizard_step = max_allowed_wizard_step
      end

      def preview_targets
        @definition = normalized_audience_definition(@campaign.target_audience_definition)
        @preview_count = ::Campaigns::Commands::BuildCampaignTargetList.preview_scope(campaign: @campaign).count
        @max_allowed_wizard_step = max_allowed_wizard_step
      end

      def new
        redirect_to wizard_web_campaigns_vaccination_campaigns_path(step: 1)
      end

      def create
        @campaign = scoped_campaigns.build(campaign_params)
        @campaign.municipality = current_municipality
        @campaign.status = "draft"

        if scoped_vaccination_param_errors?(@campaign)
          render_wizard(1, status: :unprocessable_entity)
          return
        end

        result = CommandBus.dispatch(
          ::Campaigns::Commands::CreateVaccinationCampaign,
          campaign: @campaign,
          municipality: current_municipality
        )
        if result.success
          redirect_to wizard_web_campaigns_vaccination_campaign_path(result.campaign, step: 2),
                      notice: t("cidadaobr.campaigns.vaccination_wizard.saved_step1")
        else
          render_wizard(1, status: :unprocessable_entity)
        end
      end

      def edit
        redirect_to wizard_web_campaigns_vaccination_campaign_path(@campaign, step: 1)
      end

      def update
        if scoped_vaccination_param_errors?(@campaign)
          render_wizard(1, status: :unprocessable_entity)
          return
        end

        result = CommandBus.dispatch(
          ::Campaigns::Commands::UpdateVaccinationCampaign,
          campaign: @campaign,
          attributes: campaign_params
        )
        if result.success
          if (@campaign.previous_changes.keys & STEP1_ATTRS).any?
            CommandBus.dispatch(::Campaigns::Commands::InvalidateVaccinationCampaignDraft, campaign: @campaign)
          end
          redirect_to wizard_web_campaigns_vaccination_campaign_path(@campaign, step: 2),
                      notice: t("cidadaobr.campaigns.vaccination_wizard.saved_step1")
        else
          render_wizard(1, status: :unprocessable_entity)
        end
      end

      def wizard
        if params[:id]
          @wizard_completion_step = wizard_completion_step
          @step = enforce_wizard_step!(wizard_step_param) or return
          @preview_count = preview_count_for_step(@step)
          @provisioning_result = provisioning_preview if @step == 3 && @campaign.persisted?
          @provisioning = @campaign.supply_provisioning if @step >= 3
          @targets_preview = @campaign.campaign_targets.includes(:citizen).order(priority_score: :desc).limit(20) if @step == 4
          render_wizard(@step)
        else
          @campaign = scoped_campaigns.build(
            starts_on: Date.current,
            ends_on: 7.days.from_now.to_date,
            campaign_kind: "human_immunization",
            target_audience_definition: { "min_age" => 60 }
          )
          @wizard_completion_step = 0
          @step = 1
          render_wizard(1)
        end
      end

      def update_wizard
        @step = wizard_step_param
        return unless enforce_wizard_step!(@step)

        case @step
        when 2
          previous_audience = normalized_audience_definition(@campaign.target_audience_definition)
          previous_doses = @campaign.target_doses.to_i
          attrs = audience_params
          definition = attrs[:target_audience_definition].merge("wizard_audience_saved" => true)
          attrs[:target_audience_definition] = definition
          if attrs[:target_doses].blank? && @campaign.target_doses.to_i.zero?
            count = preview_count_for_definition(definition)
            attrs[:target_doses] = count if count.positive?
          end
          result = CommandBus.dispatch(
            ::Campaigns::Commands::UpdateVaccinationCampaign,
            campaign: @campaign,
            attributes: attrs
          )
          if result.success
            audience_changed = previous_audience != normalized_audience_definition(definition)
            doses_changed = @campaign.target_doses.to_i != previous_doses
            if audience_changed || doses_changed
              CommandBus.dispatch(
                ::Campaigns::Commands::InvalidateVaccinationCampaignDraft,
                campaign: @campaign,
                keep_audience: true
              )
            end
            redirect_to wizard_web_campaigns_vaccination_campaign_path(@campaign, step: 3)
          else
            @preview_count = preview_count_for_step(2)
            render_wizard(2, status: :unprocessable_entity)
          end
        when 3
          finish_provisioning_step!
        when 4
          unless @campaign.supply_provisioning&.status == "approved"
            redirect_to wizard_web_campaigns_vaccination_campaign_path(@campaign, step: max_allowed_wizard_step),
                        alert: t("cidadaobr.campaigns.flash.build_targets_blocked")
            return
          end

          result = CommandBus.dispatch(::Campaigns::Commands::BuildCampaignTargetList, campaign: @campaign)
          redirect_after_build_targets!(result, wizard_web_campaigns_vaccination_campaign_path(@campaign, step: 4))
        else
          redirect_to wizard_web_campaigns_vaccination_campaign_path(@campaign, step: 1)
        end
      end

      def preview_provisioning
        redirect_to wizard_web_campaigns_vaccination_campaign_path(@campaign, step: 3)
      end

      def calculate_provisioning
        @step = 3
        return unless enforce_wizard_step!(3)

        finish_provisioning_step!
      end

      def build_targets
        unless @campaign.supply_provisioning&.status == "approved"
          redirect_to wizard_web_campaigns_vaccination_campaign_path(@campaign, step: max_allowed_wizard_step),
                      alert: t("cidadaobr.campaigns.flash.build_targets_blocked")
          return
        end

        result = CommandBus.dispatch(::Campaigns::Commands::BuildCampaignTargetList, campaign: @campaign)
        redirect_after_build_targets!(result, web_campaigns_vaccination_campaign_path(@campaign))
      end

      def publish
        if @campaign.status == "active"
          redirect_to web_campaigns_vaccination_campaign_path(@campaign),
                      alert: t("cidadaobr.campaigns.flash.already_published")
          return
        end

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

        result = CommandBus.dispatch(::Campaigns::Commands::PublishVaccinationCampaign, campaign: @campaign)
        if result.message.present?
          redirect_to web_campaigns_vaccination_campaign_path(@campaign), alert: result.message
          return
        end

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
        return unless params[:id]

        @campaign = scoped_campaigns.find(params[:id])
      end

      def set_form_collections
        @facilities = scoped_health_facilities.order(:name)
        @products = ImmunobiologicalProduct.where(municipality_id: current_municipality.id, active: true).order(:name)
        @rooms = ConsultationRoom.where(municipality_id: current_municipality.id, active: true).order(:name)
      end

      def set_wizard_collections
        @care_teams = scoped_care_teams.order(:name)
        @micro_areas = MicroArea.where(municipality_id: current_municipality.id).order(:code)
      end

      def wizard_step_param
        step = params[:step].to_i
        step = 1 if step < 1
        [ step, WIZARD_STEPS ].min
      end

      def render_wizard(step, **options)
        @step = step
        template = step == 1 && @campaign&.new_record? ? :wizard_step1_new : :wizard
        render template, **options
      end

      def wizard_completion_step
        return 4 if @campaign.status == "active"
        if @campaign.campaign_targets.any? && @campaign.supply_provisioning&.status == "approved"
          return 4
        end
        return 3 if @campaign.supply_provisioning&.status == "approved"
        return 2 if audience_saved? && @campaign.target_doses.to_i.positive?
        return 1 if @campaign.persisted?

        0
      end

      def max_allowed_wizard_step
        return 1 unless @campaign&.persisted?

        allowed = 2
        allowed = 3 if audience_saved? && @campaign.target_doses.to_i.positive?
        allowed = 4 if @campaign.supply_provisioning&.status == "approved"
        allowed = 4 if @campaign.status == "active"
        [ allowed, WIZARD_STEPS ].min
      end

      def enforce_wizard_step!(requested_step)
        allowed = max_allowed_wizard_step
        return requested_step if requested_step <= allowed

        redirect_to wizard_web_campaigns_vaccination_campaign_path(@campaign, step: allowed),
                    alert: t("cidadaobr.campaigns.vaccination_wizard.step_locked")
        nil
      end

      def preview_count_for_step(step)
        return 0 unless @campaign&.persisted? && step >= 2

        preview_count_for_definition(@campaign.target_audience_definition)
      end

      def preview_count_for_definition(definition)
        ::Campaigns::Commands::BuildCampaignTargetList.preview_scope(
          campaign: @campaign,
          definition: definition
        ).count
      end

      def audience_saved?
        @campaign.target_audience_definition["wizard_audience_saved"] == true
      end

      def provisioning_preview
        Inventory::ProvisioningValidator.call(
          campaign: @campaign,
          room_capacity_per_day: @campaign.room_capacity_per_day
        )
      end

      def campaign_params
        permitted = require_permitted(:vaccination_campaign, *vaccination_campaign_step1_permit_list)
        sanitized_facility_id = sanitize_scoped_health_facility_id(permitted[:health_facility_id])
        permitted[:health_facility_id] = sanitized_facility_id
        permitted[:consultation_room_id] = sanitize_scoped_consultation_room_id(
          permitted[:consultation_room_id],
          health_facility_id: sanitized_facility_id
        )
        permitted
      end

      def scoped_vaccination_param_errors?(record)
        permitted = permit_optional(:vaccination_campaign, *vaccination_campaign_step1_permit_list) ||
          ActionController::Parameters.new
        sanitized_facility_id = sanitize_scoped_health_facility_id(permitted[:health_facility_id])
        add_scoped_param_errors(
          record,
          raw_facility_id: permitted[:health_facility_id],
          raw_room_id: permitted[:consultation_room_id],
          health_facility_id: sanitized_facility_id
        )
      end

      def audience_params
        permitted = require_permitted(:vaccination_campaign, *vaccination_campaign_audience_permit_list)
        audience_permitted = permitted[:target_audience_definition] || ActionController::Parameters.new
        definition = @campaign.target_audience_definition.deep_dup

        %i[min_age max_age sex].each do |key|
          next unless audience_permitted.key?(key)

          value = audience_permitted[key]
          value.present? ? definition[key.to_s] = value : definition.delete(key.to_s)
        end
        if audience_permitted.key?(:care_team_ids)
          definition["care_team_ids"] = Array(audience_permitted[:care_team_ids]).compact_blank
        end
        if audience_permitted.key?(:micro_area_codes)
          definition["micro_area_codes"] = Array(audience_permitted[:micro_area_codes]).compact_blank
        end

        attrs = { target_audience_definition: definition }
        attrs[:target_doses] = permitted[:target_doses] if permitted.key?(:target_doses)
        attrs
      end

      def vaccination_campaign_step1_permit_list
        %i[
          name
          health_facility_id
          immunobiological_product_id
          consultation_room_id
          campaign_kind
          starts_on
          ends_on
          room_capacity_per_day
        ]
      end

      def vaccination_campaign_audience_permit_list
        [
          :target_doses,
          {
            target_audience_definition: [
              :min_age,
              :max_age,
              :sex,
              { care_team_ids: [] },
              { micro_area_codes: [] }
            ]
          }
        ]
      end

      def reject_mutations_when_active!
        return unless @campaign&.status == "active"

        redirect_to web_campaigns_vaccination_campaign_path(@campaign),
                    alert: t("cidadaobr.campaigns.flash.active_campaign_locked")
      end

      def normalized_audience_definition(definition)
        hash = definition.to_h.with_indifferent_access.except(:wizard_audience_saved)
        hash[:care_team_ids] = Array(hash[:care_team_ids]).compact_blank.sort
        hash[:micro_area_codes] = Array(hash[:micro_area_codes]).compact_blank.sort
        hash
      end

      def finish_provisioning_step!
        run_provisioning!
        if @last_provisioning_result.feasible
          redirect_to wizard_web_campaigns_vaccination_campaign_path(@campaign, step: 4),
                      notice: t("cidadaobr.campaigns.flash.created_provisioning_ok")
        else
          @wizard_completion_step = wizard_completion_step
          @provisioning_result = @last_provisioning_result
          @provisioning = @campaign.supply_provisioning
          flash.now[:alert] = t("cidadaobr.campaigns.flash.created_provisioning_blocked")
          render_wizard(3, status: :unprocessable_entity)
        end
      end

      def run_provisioning!
        @last_provisioning_result = CommandBus.dispatch(
          Inventory::Commands::PersistVaccinationProvisioning,
          campaign: @campaign
        )
      end
    end
  end
end
