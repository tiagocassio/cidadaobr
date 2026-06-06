# frozen_string_literal: true

class AddPecHttpAcceptedAtToLediBatches < ActiveRecord::Migration[8.1]
  def change
    add_column :ledi_batches, :pec_http_accepted_at, :datetime
  end
end
