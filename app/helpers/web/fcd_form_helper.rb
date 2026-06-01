# frozen_string_literal: true

module Web
  module FcdFormHelper
    def fcd_property_type_options
      Cidadaobr::LediFcdOptions::PROPERTY_TYPES.map { |code, label| [ label, code ] }
    end

    def fcd_housing_condition_options(field)
      Cidadaobr::LediFcdOptions::HOUSING_CONDITION_FIELDS.fetch(field.to_sym).map { |code, label| [ label, code ] }
    end

    def household_housing_condition_value(household, field)
      household.housing_conditions[field.to_s]
    end
  end
end
