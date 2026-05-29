# frozen_string_literal: true

module Web
  class CareTeamsController < BaseController
    before_action :require_facility_or_municipality!
    before_action :require_facility_or_municipality_write!, only: %i[new create edit update]
    before_action :set_care_team, only: %i[show edit update]
    before_action :set_health_facilities, only: %i[new create edit update]

    def index
      @pagy, @care_teams = pagy(scoped_care_teams.includes(:health_facility).order(:name))
    end

    def show
    end

    def new
      @care_team = scoped_care_teams.build
    end

    def create
      @care_team = scoped_care_teams.build(care_team_params)
      @care_team.municipality = current_municipality

      if @care_team.save
        redirect_to web_care_team_path(@care_team), notice: t("cidadaobr.care_teams.flash.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @care_team.update(care_team_params)
        redirect_to web_care_team_path(@care_team), notice: t("cidadaobr.care_teams.flash.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_care_team
      @care_team = scoped_care_teams.find(params[:id])
    end

    def set_health_facilities
      @health_facilities = scoped_health_facilities.order(:name)
    end

    def care_team_params
      permitted = params.require(:care_team).permit(:name, :ine, :health_facility_id)
      if facility_scope?
        permitted[:health_facility_id] = current_membership.health_facility_id
      elsif permitted[:health_facility_id].present?
        permitted[:health_facility_id] = scoped_health_facilities.find_by(id: permitted[:health_facility_id])&.id
      end
      permitted
    end
  end
end
