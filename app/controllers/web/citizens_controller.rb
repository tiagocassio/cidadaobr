# frozen_string_literal: true

module Web
  class CitizensController < BaseController
    before_action :set_citizen, only: :show

    def index
      @citizens = paginate(
        scoped_citizens.includes(:health_facility, :care_team).order(:full_name, :cpf)
      )
      if params[:q].present?
        query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        @citizens = @citizens.where("cpf ILIKE :q OR cns ILIKE :q OR full_name ILIKE :q", q: query)
      end
    end

    def show
    end

    private

    def set_citizen
      @citizen = scoped_citizens.find(params[:id])
    end
  end
end
