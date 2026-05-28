# frozen_string_literal: true

class LediFieldCatalog < ApplicationRecord
  self.table_name = "ledi_field_catalog"

  validates :record_type, :field_path, :data_type, :ledi_version, presence: true
  validates :field_path, uniqueness: { scope: [ :record_type, :ledi_version ] }
end
