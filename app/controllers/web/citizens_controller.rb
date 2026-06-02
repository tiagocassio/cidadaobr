# frozen_string_literal: true

module Web
  class CitizensController < BaseController
    include HouseholdFormSupport

    before_action :require_facility_or_municipality!
    before_action :require_facility_or_municipality_write!, only: %i[new create edit update]
    before_action :set_citizen, only: %i[show edit update]
    before_action :set_form_collections, only: %i[new create edit update]

    def index
      citizens = scoped_citizens.includes(:health_facility, :care_team).order(:full_name, :cpf)
      if params[:q].present?
        query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        citizens = citizens.where("cpf ILIKE :q OR cns ILIKE :q OR full_name ILIKE :q", q: query)
      end
      @pagy, @citizens = pagy(citizens)
    end

    def show
      @household_members = @citizen.household_members.includes(:household)
      @households = scoped_households.order(:street, :street_number).limit(200)
    end

    def new
      @citizen = scoped_citizens.build
      @household = build_household_for_form
    end

    def create
      result = CommandBus.dispatch(
        Territory::Commands::RegisterCitizen,
        citizen_attributes: citizen_params.to_h,
        household_attributes: household_form_requested? ? household_command_attributes : nil,
        family_reference: household_member_family_reference?
      )
      @citizen = result.citizen
      @household = result.household

      if result.success
        notice = @household ? t("cidadaobr.citizens.flash.created_with_household") : t("cidadaobr.citizens.flash.created")
        redirect_to web_citizen_path(@citizen), notice: notice
      else
        add_invalid_coordinates_flash!(result)
        repopulate_household_form! if household_form_requested?
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @household = Household.new
    end

    def update
      result = CommandBus.dispatch(
        Territory::Commands::UpdateCitizen,
        citizen: @citizen,
        citizen_attributes: citizen_params.to_h,
        household_attributes: household_form_requested? ? household_command_attributes : nil,
        family_reference: household_member_family_reference?
      )
      @citizen = result.citizen
      @household = result.household

      if result.success
        notice = @household ? t("cidadaobr.citizens.flash.updated_with_household") : t("cidadaobr.citizens.flash.updated")
        redirect_to web_citizen_path(@citizen), notice: notice
      else
        add_invalid_coordinates_flash!(result)
        repopulate_household_form! if household_form_requested?
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_citizen
      @citizen = scoped_citizens.find(params[:id])
    end

    def set_form_collections
      set_household_form_collections
    end

    def add_invalid_coordinates_flash!(result)
      return unless result.invalid_coordinates

      @citizen.errors.add(:base, t("cidadaobr.households.flash.invalid_coordinates"))
    end

    def citizen_params
      permitted = params.require(:citizen).permit(
        :cpf, :cns, :full_name, :birth_date, :sex, :health_facility_id, :care_team_id
      )

      if facility_scope?
        permitted[:health_facility_id] = current_membership.health_facility_id
        if permitted[:care_team_id].present?
          permitted[:care_team_id] = scoped_care_teams.find_by(id: permitted[:care_team_id])&.id
        end
      else
        if permitted[:health_facility_id].present?
          permitted[:health_facility_id] = scoped_health_facilities.find_by(id: permitted[:health_facility_id])&.id
        end
        if permitted[:care_team_id].present?
          permitted[:care_team_id] = scoped_care_teams.find_by(id: permitted[:care_team_id])&.id
        end
      end

      permitted
    end
  end
end
