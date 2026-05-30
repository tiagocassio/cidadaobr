# frozen_string_literal: true

# Bootstrap Portaria 3.493 indicator catalog from versioned methodology packs.
# Normative definitions live in lib/indicators/methodology_pack_definitions.rb (SOT).
# lib/indicators/methodology/3493-2024/packs/*.json is an export trail only (refreshed on seed via sync!(export_json: true)).
result = Indicators::MethodologyPackLoader.sync!(export_json: true)

Rails.logger.info(
  "[indicator_catalog] synced #{result[:catalogs]} catalog(s), #{result[:rules]} rule(s) from #{result[:packs_dir]}"
)
