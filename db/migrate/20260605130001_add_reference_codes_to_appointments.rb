# frozen_string_literal: true

class AddReferenceCodesToAppointments < ActiveRecord::Migration[8.1]
  def change
    change_table :appointments, bulk: true do |t|
      t.string :ciap2_code
      t.string :cid10_code
      t.string :sigtap_procedure_code
    end
  end
end
