# frozen_string_literal: true

class RenamePecHttpAcceptedAtToPecAcceptedAtOnLediBatches < ActiveRecord::Migration[8.1]
  def change
    rename_column :ledi_batches, :pec_http_accepted_at, :pec_accepted_at
  end
end
