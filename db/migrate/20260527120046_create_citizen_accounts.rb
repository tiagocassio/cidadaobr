# frozen_string_literal: true

class CreateCitizenAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :citizen_accounts, id: :uuid do |t|
      t.uuid :municipality_id, null: false
      t.uuid :citizen_id, null: false
      t.string :cpf, null: false
      t.string :password_digest, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :citizen_accounts, %i[municipality_id cpf], unique: true
    add_index :citizen_accounts, :citizen_id, unique: true
  end
end
