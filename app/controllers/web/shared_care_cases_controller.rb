# frozen_string_literal: true

module Web
  class SharedCareCasesController < BaseController
    before_action :require_facility_or_municipality!
    before_action :require_facility_or_municipality_write!, only: %i[new create record_evolution]
    before_action :set_case, only: %i[show record_evolution]

    def index
      @cases = SharedCareCase.where(municipality_id: current_municipality.id).includes(:citizen).order(created_at: :desc).limit(50)
    end

    def show
      @evolutions = @case.shared_care_evolutions.order(created_at: :desc)
    end

    def new
      @case = SharedCareCase.new
      @citizens = scoped_citizens.order(:full_name).limit(200)
    end

    def create
      @case = CommandBus.dispatch(
        Ledi::CreateSharedCareCase,
        citizen_id: params.require(:shared_care_case).fetch(:citizen_id),
        ciap2_code: params.dig(:shared_care_case, :ciap2_code),
        cid10_code: params.dig(:shared_care_case, :cid10_code),
        clinical_summary: params.dig(:shared_care_case, :clinical_summary)
      )
      redirect_to web_shared_care_case_path(@case), notice: t("cidadaobr.shared_care.flash.created")
    rescue ActiveRecord::RecordNotFound, ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::StatementInvalid
      @citizens = scoped_citizens.order(:full_name).limit(200)
      @case = SharedCareCase.new
      flash.now[:alert] = t("cidadaobr.shared_care.flash.invalid")
      render :new, status: :unprocessable_entity
    end

    def record_evolution
      CommandBus.dispatch(
        Ledi::RecordSharedCareEvolution,
        shared_care_case: @case,
        evolution_note: params.require(:evolution_note),
        author_user: current_user
      )
      redirect_to web_shared_care_case_path(@case), notice: t("cidadaobr.shared_care.flash.evolution_recorded")
    rescue ActiveRecord::RecordInvalid, ArgumentError, ActiveRecord::StatementInvalid
      redirect_to web_shared_care_case_path(@case), alert: t("cidadaobr.shared_care.flash.invalid")
    end

    private

    def set_case
      @case = SharedCareCase.where(municipality_id: current_municipality.id).find(params[:id])
    end
  end
end
