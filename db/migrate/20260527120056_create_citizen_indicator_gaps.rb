# frozen_string_literal: true

class CreateCitizenIndicatorGaps < ActiveRecord::Migration[8.1]
  def change
    create_table :citizen_indicator_gaps, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :citizen_id, null: false
      t.uuid :care_team_id
      t.string :indicator_code, null: false
      t.string :good_practice_code
      t.date :due_on
      t.string :status, null: false, default: "open"
      t.timestamps
    end
    add_index :citizen_indicator_gaps,
              %i[citizen_id indicator_code good_practice_code],
              name: "index_citizen_indicator_gaps_on_citizen_indicator_bp"
    add_index :citizen_indicator_gaps, %i[municipality_id indicator_code status],
              name: "index_citizen_indicator_gaps_on_municipality_indicator_status"
  end
end
