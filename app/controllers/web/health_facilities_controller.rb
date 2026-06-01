# frozen_string_literal: true

module Web
  class HealthFacilitiesController < BaseController
    before_action :require_municipality_scope!
    before_action :set_health_facility, only: %i[show edit update]

    def index
      @pagy, @health_facilities = pagy(scoped_health_facilities.order(:name))
    end

    def show
    end

    def new
      @health_facility = scoped_health_facilities.build
    end

    def create
      attrs, invalid_coordinates = location_attrs_from_params
      @health_facility = scoped_health_facilities.build(attrs)
      @health_facility.municipality = current_municipality
      @health_facility.errors.add(:latitude, t("cidadaobr.health_facilities.flash.invalid_coordinates")) if invalid_coordinates
      @health_facility.errors.add(:longitude, t("cidadaobr.health_facilities.flash.invalid_coordinates")) if invalid_coordinates

      saved = false
      tenant_scoped_transaction do
        saved = !invalid_coordinates && @health_facility.save
        raise ActiveRecord::Rollback unless saved
      end

      if saved
        redirect_to web_health_facility_path(@health_facility), notice: t("cidadaobr.health_facilities.flash.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      attrs, invalid_coordinates = location_attrs_from_params
      @health_facility.assign_attributes(attrs)
      @health_facility.errors.add(:latitude, t("cidadaobr.health_facilities.flash.invalid_coordinates")) if invalid_coordinates
      @health_facility.errors.add(:longitude, t("cidadaobr.health_facilities.flash.invalid_coordinates")) if invalid_coordinates

      saved = false
      tenant_scoped_transaction do
        saved = !invalid_coordinates && @health_facility.save
        raise ActiveRecord::Rollback unless saved
      end

      if saved
        redirect_to web_health_facility_path(@health_facility), notice: t("cidadaobr.health_facilities.flash.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_health_facility
      @health_facility = scoped_health_facilities.find(params[:id])
    end

    def location_attrs_from_params
      permitted = params.require(:health_facility).permit(:name, :cnes, :facility_service_kind, :latitude, :longitude)
      attrs = permitted.except(:latitude, :longitude)
      latitude = permitted[:latitude]
      longitude = permitted[:longitude]
      if latitude.blank? || longitude.blank?
        attrs[:location] = nil
        return [ attrs, false ]
      end

      location = Cidadaobr::GeoPoint.from_payload(latitude: latitude, longitude: longitude)
      if location
        attrs[:location] = location
        [ attrs, false ]
      else
        [ attrs, true ]
      end
    end
  end
end
