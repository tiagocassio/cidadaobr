# frozen_string_literal: true

class CreateProfessionalAvailabilityBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :professional_availability_blocks, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :health_facility_id, null: false
      t.uuid :professional_id, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :reason
      t.timestamps
    end

    add_reference :encounters, :appointment, type: :uuid, foreign_key: true, index: true
  end
end
