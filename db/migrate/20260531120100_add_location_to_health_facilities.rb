# frozen_string_literal: true

class AddLocationToHealthFacilities < ActiveRecord::Migration[8.0]
  def change
    add_column :health_facilities, :location, :st_point, geographic: true
    add_index :health_facilities, :location, using: :gist
  end
end
