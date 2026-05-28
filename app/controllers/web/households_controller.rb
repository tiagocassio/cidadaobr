# frozen_string_literal: true

module Web
  class HouseholdsController < BaseController
    MARKERS_LIMIT = 500

    before_action :set_household, only: :show

    def index
      @households = paginate(
        scoped_households.includes(:health_facility, :care_team).order(:street)
      )
    end

    def show
      @household_animals = @household.household_animals.order(:species)
      @household_animal = HouseholdAnimal.new
    end

    def map
    end

    def markers
      unless bbox_params_complete?
        return render json: []
      end

      households = scoped_households.with_location.includes(:health_facility)
      households = filter_markers_by_bbox(households)
      households = households.limit(MARKERS_LIMIT)

      render json: households.filter_map { |household|
        coords = household.coordinates
        next unless coords

        {
          id: household.id,
          lat: coords[:lat],
          lng: coords[:lng],
          label: [ household.street, household.street_number ].compact.join(", "),
          url: web_household_path(household)
        }
      }
    end

    private

    def set_household
      @household = scoped_households.find(params[:id])
    end

    def bbox_params_complete?
      %i[sw_lat sw_lng ne_lat ne_lng].all? { |key| params[key].present? }
    end

    def filter_markers_by_bbox(scope)
      bbox = Cidadaobr::GeoPoint.bbox_polygon(
        sw_lat: params[:sw_lat],
        sw_lng: params[:sw_lng],
        ne_lat: params[:ne_lat],
        ne_lng: params[:ne_lng]
      )
      return scope.none if bbox.nil?

      scope.where(scope.arel_table[:location].st_within(bbox))
    end
  end
end
