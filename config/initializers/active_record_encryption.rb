# frozen_string_literal: true

Rails.application.configure do
  if Rails.env.development? || Rails.env.test?
    config.active_record.encryption.primary_key = ENV.fetch(
      "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY",
      "cidadaobr-dev-primary-key-32chars!"
    )
    config.active_record.encryption.deterministic_key = ENV.fetch(
      "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY",
      "cidadaobr-dev-deterministic-32chars"
    )
    config.active_record.encryption.key_derivation_salt = ENV.fetch(
      "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT",
      "cidadaobr-dev-kdf-salt-32-characters"
    )
    config.active_record.encryption.support_unencrypted_data = true
  else
    config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY")
    config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY")
    config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT")
    config.active_record.encryption.support_unencrypted_data = false
  end
end
