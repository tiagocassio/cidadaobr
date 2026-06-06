# frozen_string_literal: true

class DropUnusedFuzzystrmatchExtension < ActiveRecord::Migration[8.1]
  def up
    disable_extension "fuzzystrmatch" if extension_enabled?("fuzzystrmatch")
  end

  def down
    enable_extension "fuzzystrmatch" unless extension_enabled?("fuzzystrmatch")
  end
end
