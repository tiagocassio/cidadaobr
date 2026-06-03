# frozen_string_literal: true

module Web
  class MicroAreasController < BaseController
    before_action :require_municipality_scope!
    before_action :set_micro_area, only: %i[edit update]
    before_action :set_care_teams, only: %i[new create edit update]
    before_action :set_health_facilities, only: %i[new create edit update]

    def index
      micro_areas = MicroArea.where(municipality_id: current_municipality.id)
        .includes(:care_team, :health_facilities)
        .order(:code)
      @pagy, @micro_areas = pagy(micro_areas)
      @located_household_counts = MicroArea.located_household_counts_for(@micro_areas.map(&:id))
    end

    def new
      @micro_area = MicroArea.new(municipality: current_municipality)
    end

    def create
      @micro_area = MicroArea.new
      result = CommandBus.dispatch(
        Territory::Commands::CreateMicroArea,
        micro_area: @micro_area,
        attributes: micro_area_params,
        municipality: current_municipality,
        coverage_bbox: micro_area_coverage_bbox,
        remove_coverage: remove_coverage_requested?,
        health_facility_ids: micro_area_health_facility_ids
      )
      @micro_area = result.micro_area

      if result.success
        redirect_to web_micro_areas_path, notice: t("cidadaobr.micro_areas.flash.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      result = CommandBus.dispatch(
        Territory::Commands::UpdateMicroArea,
        micro_area: @micro_area,
        attributes: micro_area_params,
        coverage_bbox: micro_area_coverage_bbox,
        remove_coverage: remove_coverage_requested?,
        health_facility_ids: micro_area_health_facility_ids
      )
      @micro_area = result.micro_area

      if result.success
        redirect_to web_micro_areas_path, notice: t("cidadaobr.micro_areas.flash.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_micro_area
      @micro_area = MicroArea.where(municipality_id: current_municipality.id).find(params[:id])
    end

    def set_care_teams
      @care_teams = scoped_care_teams.order(:name)
    end

    def set_health_facilities
      @health_facilities = HealthFacility.where(municipality_id: current_municipality.id).order(:name)
    end

    def micro_area_params
      permitted = micro_area_permitted.slice(:code, :name, :care_team_id)
      permitted[:care_team_id] = scoped_care_teams.find_by(id: permitted[:care_team_id])&.id
      permitted
    end

    def micro_area_permitted
      @micro_area_permitted ||= params.expect(
        micro_area: [
          :code,
          :name,
          :care_team_id,
          :coverage_sw_lat,
          :coverage_sw_lng,
          :coverage_ne_lat,
          :coverage_ne_lng,
          :remove_coverage,
          { health_facility_ids: [] }
        ]
      )
    end

    def micro_area_health_facility_ids
      Array(micro_area_permitted[:health_facility_ids]).compact_blank
    end

    def remove_coverage_requested?
      ActiveModel::Type::Boolean.new.cast(micro_area_permitted[:remove_coverage])
    end

    def micro_area_coverage_bbox
      permitted = micro_area_permitted
      return nil if permitted[:coverage_sw_lat].blank?

      Territory::MicroAreaCoverage.build_polygon(
        sw_lat: permitted[:coverage_sw_lat],
        sw_lng: permitted[:coverage_sw_lng],
        ne_lat: permitted[:coverage_ne_lat],
        ne_lng: permitted[:coverage_ne_lng]
      )
    end
  end
end
