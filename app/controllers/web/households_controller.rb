# frozen_string_literal: true

module Web
  class HouseholdsController < BaseController
    include HouseholdFormSupport

    before_action :require_facility_or_municipality!
    before_action :require_facility_or_municipality_write!, only: %i[new create edit update]
    before_action :set_household, only: %i[show edit update]
    before_action :set_household_form_collections, only: %i[new create edit update]

    def index
      @pagy, @households = pagy(
        scoped_households.includes(:health_facility, :care_team).order(:street, :street_number)
      )
    end

    def show
      @household_animals = @household.household_animals.order(:species)
      @household_animal = HouseholdAnimal.new
      @citizens_for_select = scoped_citizens.order(:full_name).limit(200)
    end

    def new
      @household = scoped_households.build
    end

    def create
      @household = scoped_households.build
      valid, invalid_coordinates = assign_household_from_params(@household)

      if invalid_coordinates
        @household.errors.add(:base, t("cidadaobr.households.flash.invalid_coordinates"))
        render :new, status: :unprocessable_entity
        return
      end

      if valid && @household.save
        redirect_to web_household_path(@household), notice: t("cidadaobr.households.flash.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      valid, invalid_coordinates = assign_household_from_params(@household)

      if invalid_coordinates
        @household.errors.add(:base, t("cidadaobr.households.flash.invalid_coordinates"))
        render :edit, status: :unprocessable_entity
        return
      end

      if valid && @household.save
        redirect_to web_household_path(@household), notice: t("cidadaobr.households.flash.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def map
    end

    def markers
      unless bbox_params_complete?
        @markers = []
        return render :markers, formats: :json
      end

      households = scoped_households.with_location.includes(:health_facility)
      households = filter_markers_by_bbox(households)
      households = households.limit(MARKERS_LIMIT)

      @markers = households.filter_map { |household|
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

      render :markers, formats: :json
    end

    private

    MARKERS_LIMIT = 500

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

      column = "#{scope.connection.quote_table_name(scope.table_name)}.#{scope.connection.quote_column_name(:location)}"
      sql, bind = Cidadaobr::GeoPoint.within_geography_sql(column: column, region: bbox)
      scope.where(sql, bind)
    end
  end
end
