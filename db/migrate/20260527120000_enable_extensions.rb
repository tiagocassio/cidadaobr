# frozen_string_literal: true

class EnableExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    enable_extension "postgis" unless extension_enabled?("postgis")
  end
end
