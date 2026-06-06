# frozen_string_literal: true

class AddPecIntegrationToMunicipalities < ActiveRecord::Migration[8.1]
  def change
    change_table :municipalities, bulk: true do |t|
      t.string :pec_base_url
      t.string :pec_api_token
    end
  end
end
