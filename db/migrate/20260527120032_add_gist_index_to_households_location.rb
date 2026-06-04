# frozen_string_literal: true

class AddGistIndexToHouseholdsLocation < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :households, :location, using: :gist, algorithm: :concurrently, if_not_exists: true
  end
end
