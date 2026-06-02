# frozen_string_literal: true

module Web
  class CareTeamsController < BaseController
    before_action :require_facility_or_municipality!
    before_action :require_facility_or_municipality_write!, only: %i[new create edit update]
    before_action :set_care_team, only: %i[show edit update]
    before_action :set_health_facilities, only: %i[new create edit update]

    def index
      @pagy, @care_teams = pagy(scoped_care_teams.order(:name))
      assign_health_facility_names(@care_teams)
    end

    def show
      assign_health_facility_names([ @care_team ])
    end

    def new
      @care_team = scoped_care_teams.build
    end

    def create
      @care_team = scoped_care_teams.build
      result = CommandBus.dispatch(
        Territory::Commands::CreateCareTeam,
        care_team: @care_team,
        attributes: care_team_params,
        municipality: current_municipality
      )
      @care_team = result.care_team

      if result.success
        redirect_to web_care_team_path(@care_team), notice: t("cidadaobr.care_teams.flash.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      result = CommandBus.dispatch(
        Territory::Commands::UpdateCareTeam,
        care_team: @care_team,
        attributes: care_team_params
      )
      @care_team = result.care_team

      if result.success
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
      permitted = params.require(:care_team).permit(:name, :ine, :health_facility_id, :team_kind)
      if facility_scope?
        permitted[:health_facility_id] = current_membership.health_facility_id
      elsif permitted[:health_facility_id].present?
        permitted[:health_facility_id] = scoped_health_facilities.find_by(id: permitted[:health_facility_id])&.id
      end
      permitted
    end

    def assign_health_facility_names(teams)
      facility_ids = teams.map(&:health_facility_id).compact.uniq
      @health_facility_names_by_id =
        if facility_ids.empty?
          {}
        else
          scoped_health_facilities.where(id: facility_ids).pluck(:id, :name).to_h
        end
    end
  end
end
