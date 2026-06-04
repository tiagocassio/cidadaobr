# frozen_string_literal: true

class HardenIndicatorGapUniqueness < ActiveRecord::Migration[8.1]
  def change
    add_index :citizen_indicator_gaps,
              "citizen_id, indicator_code, COALESCE(good_practice_code, '')",
              unique: true,
              where: "status = 'open'",
              name: "index_citizen_indicator_gaps_open_unique"
  end
end
