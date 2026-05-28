# frozen_string_literal: true

module Web
  class HealthFacilitiesController < BaseController
    before_action :require_municipality_scope!
    before_action :set_health_facility, only: %i[show edit update]

    def index
      @health_facilities = scoped_health_facilities.order(:name)
    end

    def show
    end

    def new
      @health_facility = scoped_health_facilities.build
    end

    def create
      @health_facility = scoped_health_facilities.build(health_facility_params)
      @health_facility.municipality = current_municipality

      if @health_facility.save
        redirect_to web_health_facility_path(@health_facility), notice: "UBS cadastrada com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @health_facility.update(health_facility_params)
        redirect_to web_health_facility_path(@health_facility), notice: "UBS atualizada com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_health_facility
      @health_facility = scoped_health_facilities.find(params[:id])
    end

    def health_facility_params
      params.require(:health_facility).permit(:name, :cnes, :facility_service_kind)
    end
  end
end
