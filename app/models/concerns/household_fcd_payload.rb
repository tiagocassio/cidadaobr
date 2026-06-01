# frozen_string_literal: true

module HouseholdFcdPayload
  extend ActiveSupport::Concern

  HOUSING_CONDITION_KEYS = Cidadaobr::LediFcdOptions::HOUSING_CONDITION_FIELDS.keys.map(&:to_s).freeze
  HOUSING_CONDITION_STRING_KEYS = %w[nu_moradores nu_comodos].freeze

  included do
    validate :fcd_territorial_registration, if: :web_fcd_registration?
    attr_accessor :web_fcd_registration
  end

  def to_fcd_payload
    address = {
      "nome_logradouro" => street,
      "numero" => street_number,
      "complemento" => complement,
      "bairro" => neighborhood,
      "cep" => postal_code,
      "codigo_ibge_municipio" => ibge_code,
      "ponto_referencia" => reference_point,
      "telefone_contato" => contact_phone,
      "telefone_residencia" => residence_phone,
      "st_sem_numero" => no_street_number,
      "st_fora_area" => outside_micro_area,
      "micro_area" => micro_area_code
    }.compact

    condition_payload = housing_conditions.to_h.stringify_keys.each_with_object({}) do |(key, value), hash|
      next if value.blank?

      camel = key.camelize(:lower)
      hash[camel] = HOUSING_CONDITION_STRING_KEYS.include?(key) ? value.to_s : value.to_i
    end

    payload = {
      "micro_area" => micro_area_code,
      "tipo_de_imovel" => property_type,
      "endereco_local_permanencia" => address,
      "st_animais_no_domicilio" => animals_on_premises
    }
    payload["condicao_moradia"] = condition_payload if condition_payload.present?
    coords = coordinates
    if coords
      payload["latitude"] = coords[:lat]
      payload["longitude"] = coords[:lng]
    end
    payload.compact
  end

  private

  def web_fcd_registration?
    web_fcd_registration == true
  end

  def fcd_territorial_registration
    unless outside_micro_area?
      errors.add(:micro_area_code, :blank) if micro_area_code.blank?
    end

    errors.add(:property_type, :blank) if property_type.blank?

    address_present = postal_code.present? || street.present? || neighborhood.present?
    errors.add(:base, :fcd_address_incomplete) unless address_present

    errors.add(:street, :blank) if street.blank?

    if no_street_number? && street_number.present?
      errors.add(:street_number, :present_when_sem_numero)
    elsif !no_street_number? && street_number.blank?
      errors.add(:street_number, :blank)
    end

    validate_housing_conditions_codes
  end

  def validate_housing_conditions_codes
    housing_conditions.each do |key, value|
      next if value.blank?
      next if HOUSING_CONDITION_STRING_KEYS.include?(key.to_s)

      allowed = Cidadaobr::LediFcdOptions::HOUSING_CONDITION_FIELDS[key.to_sym]
      next if allowed&.key?(value.to_i)

      errors.add(:housing_conditions, :invalid_code, key: key)
    end
  end
end
