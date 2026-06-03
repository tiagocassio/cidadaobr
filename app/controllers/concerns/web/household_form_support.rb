# frozen_string_literal: true

module Web
  module HouseholdFormSupport
    extend ActiveSupport::Concern

    included do
      helper_method :household_form_requested? if respond_to?(:helper_method)
    end

    private

    def household_form_requested?
      return false unless params.key?(:household)

      ActiveModel::Type::Boolean.new.cast(household_permitted[:include])
    end

    def set_household_form_collections
      @health_facilities = scoped_health_facilities.order(:name)
      @care_teams = scoped_care_teams.includes(:health_facility).order(:name)
      @micro_areas = MicroArea.where(municipality_id: current_municipality.id).order(:code)
    end

    def build_household_for_form
      household = Household.new(household_scalar_attributes)
      household.housing_conditions = household_housing_conditions
      household
    end

    def repopulate_household_form!
      @household ||= scoped_households.build
      valid, invalid_coordinates = preview_assign_household_from_params(@household)
      @household.errors.add(:base, t("cidadaobr.households.flash.invalid_coordinates")) if invalid_coordinates
      @household unless valid
    end

    def household_command_attributes
      raw = household_permitted
      attrs = sanitize_household_facility_team!(household_scalar_attributes.to_h.stringify_keys)
      attrs["latitude"] = raw[:latitude]
      attrs["longitude"] = raw[:longitude]
      attrs["housing_conditions"] = household_housing_conditions
      attrs
    end

    def household_scalar_attributes
      household_permitted.except(:latitude, :longitude, :family_reference, :housing_conditions, :include)
    end

    def household_housing_conditions
      raw = household_permitted[:housing_conditions]
      return {} if raw.blank?

      raw.to_h.compact_blank
    end

    def household_permitted
      return @household_permitted if defined?(@household_permitted)

      @household_permitted = params.permit(
        household: [
          :include,
          :street,
          :street_number,
          :complement,
          :neighborhood,
          :postal_code,
          :micro_area_code,
          :health_facility_id,
          :care_team_id,
          :latitude,
          :longitude,
          :property_type,
          :reference_point,
          :no_street_number,
          :outside_micro_area,
          :contact_phone,
          :residence_phone,
          :animals_on_premises,
          :family_reference,
          { housing_conditions: Household::HOUSING_CONDITION_KEYS + Household::HOUSING_CONDITION_STRING_KEYS }
        ]
      )[:household] || ActionController::Parameters.new
    end

    def household_location_from_params(raw)
      latitude = raw[:latitude]
      longitude = raw[:longitude]
      return [ nil, false ] if latitude.blank? || longitude.blank?

      location = Cidadaobr::GeoPoint.from_payload(latitude: latitude, longitude: longitude)
      return [ nil, true ] unless location

      [ location, false ]
    end

    def sanitize_household_facility_team!(attrs)
      if facility_scope?
        attrs["health_facility_id"] = current_membership.health_facility_id
        if attrs["care_team_id"].present?
          attrs["care_team_id"] = scoped_care_teams.find_by(id: attrs["care_team_id"])&.id
        end
      else
        if attrs["health_facility_id"].present?
          attrs["health_facility_id"] = scoped_health_facilities.find_by(id: attrs["health_facility_id"])&.id
        end
        if attrs["care_team_id"].present?
          attrs["care_team_id"] = scoped_care_teams.find_by(id: attrs["care_team_id"])&.id
        end
      end
      attrs
    end

    def household_member_family_reference?
      ActiveModel::Type::Boolean.new.cast(household_permitted[:family_reference])
    end

    def preview_assign_household_from_params(household)
      raw = household_permitted
      location, invalid_coordinates = household_location_from_params(raw)
      return [ false, true ] if invalid_coordinates

      attrs = sanitize_household_facility_team!(household_scalar_attributes.to_h.stringify_keys)
      attrs["location"] = location
      attrs["no_street_number"] = ActiveModel::Type::Boolean.new.cast(attrs["no_street_number"]) || false
      attrs["outside_micro_area"] = ActiveModel::Type::Boolean.new.cast(attrs["outside_micro_area"]) || false
      attrs["animals_on_premises"] = ActiveModel::Type::Boolean.new.cast(attrs["animals_on_premises"]) || false
      household.assign_attributes(attrs)
      household.housing_conditions = household_housing_conditions
      household.web_fcd_registration = true
      household.municipality = current_municipality
      household.ibge_code = current_municipality.ibge_code

      [ household.valid?, false ]
    end
  end
end
