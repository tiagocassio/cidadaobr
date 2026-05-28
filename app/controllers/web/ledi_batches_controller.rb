# frozen_string_literal: true

module Web
  class LediBatchesController < BaseController
    before_action :set_ledi_batch, only: :show

    def index
      ledi_batches = scoped_ledi_batches.includes(:health_facility, :care_team).order(created_at: :desc)
      if params[:status].present? && LediBatch::STATUSES.include?(params[:status])
        ledi_batches = ledi_batches.where(status: params[:status])
      end
      @pagy, @ledi_batches = pagy(ledi_batches)
    end

    def show
      @transport_records = @ledi_batch.transport_records.includes(:clinical_record).order(:created_at)
    end

    private

    def set_ledi_batch
      @ledi_batch = scoped_ledi_batches.find(params[:id])
    end
  end
end
