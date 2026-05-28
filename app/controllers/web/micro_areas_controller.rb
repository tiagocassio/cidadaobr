# frozen_string_literal: true

module Web
  class MicroAreasController < BaseController
    before_action :require_municipality_scope!
    before_action :set_micro_area, only: %i[edit update]
    before_action :set_care_teams, only: %i[new create edit update]
    before_action :set_health_facilities, only: %i[new create edit update]

    def index
      @micro_areas = MicroArea.where(municipality_id: current_municipality.id)
        .includes(:care_team, :health_facilities)
        .order(:code)
    end

    def new
      @micro_area = MicroArea.new(municipality: current_municipality)
    end

    def create
      @micro_area = MicroArea.new(micro_area_params)
      @micro_area.municipality = current_municipality
      assign_coverage!

      if @micro_area.errors.none? && @micro_area.save
        sync_facility_coverages!
        redirect_to web_micro_areas_path, notice: "Microárea cadastrada com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      attributes = micro_area_params
      assign_coverage!

      if @micro_area.errors.none? && @micro_area.update(attributes)
        sync_facility_coverages!
        redirect_to web_micro_areas_path, notice: "Microárea atualizada com sucesso."
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

    def sync_facility_coverages!
      @micro_area.sync_health_facility_coverages!(Array(params.dig(:micro_area, :health_facility_ids)).compact_blank)
    end

    def micro_area_params
      permitted = params.require(:micro_area).permit(:code, :name, :care_team_id)
      team = scoped_care_teams.find_by(id: permitted[:care_team_id])
      permitted[:care_team_id] = team&.id
      permitted
    end

    def coverage_params_present?
      params.dig(:micro_area, :coverage_sw_lat).present?
    end

    def remove_coverage_requested?
      ActiveModel::Type::Boolean.new.cast(params.dig(:micro_area, :remove_coverage))
    end

    def assign_coverage!
      if remove_coverage_requested?
        @micro_area.coverage = nil
        return
      end

      return unless coverage_params_present?

      coverage = build_coverage
      if coverage
        @micro_area.coverage = coverage
      else
        @micro_area.errors.add(:base, "Cobertura geográfica inválida")
      end
    end

    def build_coverage
      Cidadaobr::GeoPoint.bbox_polygon(
        sw_lat: params.dig(:micro_area, :coverage_sw_lat),
        sw_lng: params.dig(:micro_area, :coverage_sw_lng),
        ne_lat: params.dig(:micro_area, :coverage_ne_lat),
        ne_lng: params.dig(:micro_area, :coverage_ne_lng)
      )
    end
  end
end
