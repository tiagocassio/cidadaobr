# frozen_string_literal: true

class AddRejectionFieldsToLediBatches < ActiveRecord::Migration[8.1]
  def change
    change_table :ledi_batches, bulk: true do |t|
      t.text :rejection_reason
      t.datetime :rejected_at
    end
  end
end
