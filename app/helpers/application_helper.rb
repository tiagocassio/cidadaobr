# frozen_string_literal: true

module ApplicationHelper
  include Pagy::Frontend

  def appointment_status_label(status)
    enum_label("cidadaobr.appointments.statuses", status)
  end

  def appointment_channel_label(channel)
    enum_label("cidadaobr.appointments.channels", channel)
  end

  def facility_service_kind_label(kind)
    enum_label("cidadaobr.health_facilities.service_kinds", kind)
  end

  def health_facility_name_for(team, names_by_id: @health_facility_names_by_id)
    return t("cidadaobr.common.empty") if team.health_facility_id.blank?

    names_by_id&.[](team.health_facility_id) || t("cidadaobr.common.empty")
  end

  def citizen_sex_label(sex)
    return t("cidadaobr.common.empty") if sex.blank?

    key = { "F" => "female", "M" => "male", "I" => "indeterminate" }[sex.to_s]
    return t("cidadaobr.citizens.sex_options.#{key}") if key

    t("cidadaobr.citizens.sex_options.unknown")
  end

  def membership_scope_label(scope)
    enum_label("cidadaobr.users.scopes", scope)
  end

  def membership_role_label(role_code)
    enum_label("cidadaobr.users.roles", role_code)
  end

  def ledi_batch_status_label(status)
    enum_label("cidadaobr.ledi_batches.statuses", status)
  end

  def transport_record_status_label(status)
    enum_label("cidadaobr.ledi_batches.transport_records.statuses", status)
  end

  def clinical_record_validation_status_label(status)
    enum_label("cidadaobr.ledi_batches.clinical_records.validation_statuses", status)
  end

  def platform_event_type_label(event_type)
    return t("cidadaobr.common.empty") if event_type.blank?

    key = event_type.tr(".", "_")
    scope = "cidadaobr.platform_events"
    return I18n.t("#{scope}.#{key}") if I18n.exists?("#{scope}.#{key}")

    I18n.t("#{scope}.unknown", event_type: event_type)
  end

  def serialized_type_label(code)
    return t("cidadaobr.common.empty") if code.blank?

    entry = Ledi::SerializedType.find(code)
    if entry
      clinical_record_type_label(entry.record_type)
    else
      t("cidadaobr.ledi_batches.transport_records.unknown_serialized_type", code: code)
    end
  end

  def clinical_record_type_label(record_type)
    return t("cidadaobr.common.empty") if record_type.blank?

    key = record_type.to_s.downcase
    scope = "cidadaobr.ledi_batches.clinical_records.types"
    return I18n.t("#{scope}.#{key}") if I18n.exists?("#{scope}.#{key}")

    record_type
  end

  def health_facility_service_kind_options
    HealthFacility::SERVICE_KINDS.map do |kind|
      [ facility_service_kind_label(kind), kind ]
    end
  end

  def user_membership_role_options
    UserMunicipalityMembership::WEB_ROLE_CODES.map do |code|
      [ membership_role_label(code), code ]
    end
  end

  private

  def enum_label(i18n_scope, value)
    return t("cidadaobr.common.empty") if value.blank?

    key = "#{i18n_scope}.#{value}"
    return I18n.t(key) if I18n.exists?(key)

    I18n.t("cidadaobr.common.unknown_enum", value: value)
  end
end
