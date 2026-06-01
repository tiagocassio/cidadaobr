# frozen_string_literal: true

module Web
  module HouseholdFormSupport
    extend ActiveSupport::Concern

    HOUSEHOLD_PERMITTED = [
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
    ].freeze

    included do
      helper_method :household_form_requested? if respond_to?(:helper_method)
    end

    private

    def household_form_requested?
      ActiveModel::Type::Boolean.new.cast(params.dig(:household, :include))
    end

    def set_household_form_collections
      @health_facilities = scoped_health_facilities.order(:name)
      @care_teams = scoped_care_teams.includes(:health_facility).order(:name)
      @micro_areas = MicroArea.where(municipality_id: current_municipality.id).order(:code)
    end

    def build_household_for_form
      household = Household.new(household_scalar_attributes)
      household.housing_conditions = household_housing_conditions_from_params
      household
    end

    def repopulate_household_form!
      @household ||= scoped_households.build
      assign_household_from_params(@household)
    end

    def household_scalar_attributes
      household_permitted_raw.except(:latitude, :longitude, :family_reference, :housing_conditions)
    end

    def household_housing_conditions_from_params
      raw = household_permitted_raw[:housing_conditions]
      return {} unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

      raw.to_h.compact_blank
    end

    def household_permitted_raw
      params.fetch(:household, {}).permit(*HOUSEHOLD_PERMITTED)
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
        attrs[:health_facility_id] = current_membership.health_facility_id
        if attrs[:care_team_id].present?
          attrs[:care_team_id] = scoped_care_teams.find_by(id: attrs[:care_team_id])&.id
        end
      else
        if attrs[:health_facility_id].present?
          attrs[:health_facility_id] = scoped_health_facilities.find_by(id: attrs[:health_facility_id])&.id
        end
        if attrs[:care_team_id].present?
          attrs[:care_team_id] = scoped_care_teams.find_by(id: attrs[:care_team_id])&.id
        end
      end
      attrs
    end

    def apply_household_municipality!(household)
      household.municipality = current_municipality
      household.ibge_code = current_municipality.ibge_code
    end

    def default_household_from_citizen!(household, citizen)
      household.health_facility_id ||= citizen.health_facility_id
      household.care_team_id ||= citizen.care_team_id
    end

    def household_member_family_reference?
      ActiveModel::Type::Boolean.new.cast(params.dig(:household, :family_reference))
    end

    def assign_household_from_params(household)
      raw = household_permitted_raw
      location, invalid_coordinates = household_location_from_params(raw)
      return [ false, true ] if invalid_coordinates

      attrs = sanitize_household_facility_team!(
        raw.except(:latitude, :longitude, :family_reference, :housing_conditions).to_h
      )
      attrs[:location] = location
      attrs[:no_street_number] = ActiveModel::Type::Boolean.new.cast(attrs[:no_street_number]) || false
      attrs[:outside_micro_area] = ActiveModel::Type::Boolean.new.cast(attrs[:outside_micro_area]) || false
      attrs[:animals_on_premises] = ActiveModel::Type::Boolean.new.cast(attrs[:animals_on_premises]) || false
      household.assign_attributes(attrs)
      household.housing_conditions = household_housing_conditions_from_params
      household.web_fcd_registration = true
      apply_household_municipality!(household)

      [ household.valid?, false ]
    end

    def save_citizen_with_optional_household!
      @household = scoped_households.build if household_form_requested?

      saved = false
      ActiveRecord::Base.transaction do
        saved = yield
        if saved && @household
          valid, invalid_coordinates = assign_household_from_params(@household)
          if invalid_coordinates
            @household.errors.add(:base, t("cidadaobr.households.flash.invalid_coordinates"))
            saved = false
          elsif !valid || !persist_household_for_citizen!(@citizen, @household)
            saved = false
          end
        end
        raise ActiveRecord::Rollback unless saved
      end
      saved
    end

    def persist_household_for_citizen!(citizen, household)
      default_household_from_citizen!(household, citizen)
      return false unless household.save

      household.household_members.create!(
        citizen: citizen,
        family_reference: household_member_family_reference?
      )
      true
    end
  end
end
