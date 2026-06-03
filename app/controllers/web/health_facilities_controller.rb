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
      @health_facility = scoped_health_facilities.build
      result = CommandBus.dispatch(
        Territory::Commands::CreateHealthFacility,
        health_facility: @health_facility,
        attributes: health_facility_params.to_h,
        municipality: current_municipality
      )
      @health_facility = result.health_facility

      if result.success
        redirect_to web_health_facility_path(@health_facility), notice: t("cidadaobr.health_facilities.flash.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      result = CommandBus.dispatch(
        Territory::Commands::UpdateHealthFacility,
        health_facility: @health_facility,
        attributes: health_facility_params.to_h
      )
      @health_facility = result.health_facility

      if result.success
        redirect_to web_health_facility_path(@health_facility), notice: t("cidadaobr.health_facilities.flash.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_health_facility
      @health_facility = scoped_health_facilities.find(params[:id])
    end

    def health_facility_params
      params.expect(health_facility: %i[name cnes facility_service_kind latitude longitude])
    end
  end
end
