# frozen_string_literal: true

class CreateTeamSatisfactionSurveyScores < ActiveRecord::Migration[8.0]
  def change
    create_table :team_satisfaction_survey_scores, id: :uuid do |t|
      t.references :municipality, null: false, foreign_key: true, type: :uuid
      t.references :care_team, null: false, foreign_key: true, type: :uuid
      t.date :reference_month, null: false
      t.decimal :score, precision: 4, scale: 2, null: false

      t.timestamps
    end

    add_index :team_satisfaction_survey_scores, %i[care_team_id reference_month], unique: true,
              name: "index_team_sat_scores_on_team_and_month"
  end
end
