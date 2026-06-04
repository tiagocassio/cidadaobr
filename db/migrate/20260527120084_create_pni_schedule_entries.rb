# frozen_string_literal: true

class CreatePniScheduleEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :pni_schedule_entries, id: :uuid do |t|
      t.integer :calendar_year, null: false
      t.string :age_group, null: false
      t.date :effective_from, null: false
      t.date :effective_until
      t.string :immunobiological_code, null: false
      t.string :immunobiological_name, null: false
      t.string :dose_code, null: false
      t.string :dose_label
      t.integer :min_age_days, null: false, default: 0
      t.integer :max_age_days, null: false
      t.string :strategy
      t.jsonb :aliases, default: [], null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :pni_schedule_entries,
              %i[calendar_year age_group immunobiological_code dose_code],
              unique: true,
              name: "index_pni_schedule_entries_on_year_age_group_code_dose"
    add_index :pni_schedule_entries, %i[age_group active effective_from]
  end
end
