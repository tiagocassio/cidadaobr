# frozen_string_literal: true

module Web
  class CitizensController < BaseController
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
    end

    def create
      @citizen = scoped_citizens.build(citizen_params)
      @citizen.municipality = current_municipality

      if @citizen.save
        redirect_to web_citizen_path(@citizen), notice: "Cidadão cadastrado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @citizen.update(citizen_params)
        redirect_to web_citizen_path(@citizen), notice: "Cidadão atualizado com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_citizen
      @citizen = scoped_citizens.find(params[:id])
    end

    def set_form_collections
      @health_facilities = scoped_health_facilities.order(:name)
      @care_teams = scoped_care_teams.includes(:health_facility).order(:name)
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
