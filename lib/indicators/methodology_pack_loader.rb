# frozen_string_literal: true

module Indicators
  module MethodologyPackLoader
    PACKS_DIR = Rails.root.join("lib/indicators/methodology/3493-2024/packs").freeze
    METHODOLOGY_VERSION = "3493/2024"

    module_function

    def sync!(export_json: false)
      packs = load_packs
      catalog_codes = packs.map { |p| p.dig("catalog", "code") }.uniq
      active_rule_keys = []

      ActiveRecord::Base.transaction do
        deactivate_non_portaria!(catalog_codes)

        packs.group_by { |p| p.dig("catalog", "code") }.each do |code, code_packs|
          catalog_meta = code_packs.first.fetch("catalog")
          upsert_catalog!(catalog_meta)

          code_packs.each do |pack|
            upsert_rule!(code: code, pack: pack)
            active_rule_keys << [ code, pack.fetch("rule_code") ]
          end
        end

        prune_stale_rules!(active_rule_keys)
      end

      if export_json
        begin
          ensure_pack_json_export!
        rescue StandardError => error
          raise "MethodologyPackLoader: DB synced but JSON export failed — #{error.message}", cause: error
        end
      end

      {
        catalogs: catalog_codes.size,
        rules: packs.size,
        packs_dir: PACKS_DIR.to_s
      }
    end

    def load_packs
      MethodologyPackDefinitions.all
    end

    def ensure_pack_json_export!
      FileUtils.mkdir_p(PACKS_DIR)
      staging = nil
      packs = MethodologyPackDefinitions.all
      expected_paths = packs.map do |pack|
        PACKS_DIR.join("#{pack.dig('catalog', 'code')}.#{pack.fetch('rule_code')}.json")
      end

      staging = PACKS_DIR.join(".export-staging-#{Process.pid}")
      FileUtils.mkdir_p(staging)

      packs.each do |pack|
        code = pack.dig("catalog", "code")
        rule_code = pack.fetch("rule_code")
        path = staging.join("#{code}.#{rule_code}.json")
        path.write("#{JSON.pretty_generate(pack)}\n")
      end

      staging.glob("*.json").each do |path|
        FileUtils.mv(path, PACKS_DIR.join(path.basename), force: true)
      end

      PACKS_DIR.glob("*.json").each do |path|
        FileUtils.rm_f(path) unless expected_paths.include?(path)
      end
    ensure
      FileUtils.rm_rf(staging) if staging && Dir.exist?(staging)
    end

    def upsert_catalog!(meta)
      code = meta.fetch("code")
      catalog = IndicatorCatalog.find_or_initialize_by(code: code)
      catalog.assign_attributes(
        name: I18n.t!("cidadaobr.indicators.catalog.#{code}.name"),
        funding_component: meta.fetch("funding_component"),
        team_kind: meta.fetch("team_kind"),
        methodology_version: meta.fetch("methodology_version", METHODOLOGY_VERSION),
        periodicity: meta.fetch("periodicity", "quarterly"),
        display_order: meta.fetch("display_order"),
        active: true
      )
      catalog.save!
      catalog
    end

    def upsert_rule!(code:, pack:)
      catalog = IndicatorCatalog.find_by!(code: code)
      expression = build_expression(code: code, pack: pack)

      IndicatorRule.find_or_initialize_by(indicator_catalog: catalog, rule_code: pack.fetch("rule_code")).tap do |rule|
        rule.rule_kind = "good_practice"
        rule.expression = expression
        rule.save!
      end
    end

    def build_expression(code:, pack:)
      expr = pack.fetch("expression").stringify_keys
      expression = {
        "version" => "dsl_v1",
        "indicator_code" => code,
        "methodology_version" => METHODOLOGY_VERSION,
        "denominator" => expr.fetch("denominator"),
        "numerator" => expr.fetch("numerator")
      }

      %w[good_practice_code team_score_mode skip_citizen_gaps skip_team_score
         score_scale linkage_components linkage_sat_bonus caps_linkage_tier].each do |key|
        expression[key] = expr[key] if expr.key?(key)
      end

      expression["good_practice_code"] = pack["good_practice_code"] if pack["good_practice_code"].present?

      merge_methodology_metadata!(expression, pack)
      expression
    end

    def merge_methodology_metadata!(expression, pack)
      expression["source_ref"] = pack["source_ref"] if pack["source_ref"].present?
      summary = {}
      summary["numerator_summary"] = pack["numerator_summary"] if pack["numerator_summary"].present?
      summary["denominator_summary"] = pack["denominator_summary"] if pack["denominator_summary"].present?
      summary["record_types"] = pack["record_types"] if pack["record_types"].present?
      expression["methodology_summary"] = summary if summary.present?
    end

    def deactivate_non_portaria!(active_codes)
      IndicatorCatalog
        .where(code: IndicatorCatalog::PORTARIA_3493_CODES)
        .where.not(code: active_codes)
        .where(active: true)
        .update_all(active: false, updated_at: Time.current)
    end

    # Safe to hard-delete: no other tables FK to indicator_rules.id (gaps use good_practice_code).
    def prune_stale_rules!(active_rule_keys)
      active_by_code = active_rule_keys.group_by(&:first).transform_values { |pairs| pairs.map(&:last) }

      IndicatorCatalog.where(code: IndicatorCatalog::PORTARIA_3493_CODES).find_each do |catalog|
        active_codes = active_by_code[catalog.code]
        scope = IndicatorRule.where(indicator_catalog: catalog)
        if active_codes.nil?
          scope.delete_all
        else
          scope.where.not(rule_code: active_codes).delete_all
        end
      end
    end

    def audit_report
      packs = MethodologyPackDefinitions.all
      db_rules = IndicatorRule.joins(:indicator_catalog).where(indicator_catalog: RuleCatalog.active_portaria_attributes).count
      disk = CoverageAudit.load_disk_packs
      resolver_types = Indicators::CoverageAudit.resolver_types

      {
        packs_defined: packs.size,
        packs_on_disk: disk.fetch(:valid).size,
        packs_unreadable_on_disk: disk.fetch(:unreadable).size,
        rules_in_db: db_rules,
        resolver_types: resolver_types,
        missing_resolvers: Indicators::CoverageAudit.missing_resolvers_for(packs)
      }
    end
  end
end
