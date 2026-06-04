# frozen_string_literal: true

module Indicators
  module CoverageAudit
    EXPECTED_MATRIX_ROWS = 53
    CITIZEN_SCOPE_TYPES = %w[
      citizens_on_team citizens_with_condition citizens_age_gte citizens_age_lte citizens_age_between citizens_sex_female
    ].freeze

    CLINICAL_EVIDENCE_TYPES = %w[
      registration_complete registration_updated_mici registration_within_team_limit
      clinical_predicate appointment_in_quadrimester encounter_in_window emulti_encounter_count
      mici_micdt_complete fci_updated_within contact_and_attendance satisfaction_survey
      consult_count_gte anthropometry_count_gte visit_count_gte acs_two_visit_schedule blood_pressure_count_gte
      first_consult_by_age first_prenatal_consult vaccination_present vaccination_calendar vaccination_immunobiological
      gestational_vaccination_immunobiological gestational_clinical_predicate gestational_evidence_count_gte
      puerperium_consult puerperium_visit fci_flag_present microarea_linked
    ].freeze

    TEAM_SCORE_MODES = %w[
      linkage_aggregate procedure_ratio programmed_attendance_ratio good_practices_pct
    ].freeze

    module_function

    def resolver_types
      { citizen_scope: CITIZEN_SCOPE_TYPES, clinical_evidence: CLINICAL_EVIDENCE_TYPES, team_score_modes: TEAM_SCORE_MODES }
    end

    def missing_resolvers_for(packs)
      missing = []
      packs.each do |pack|
        expr = pack.fetch("expression")
        walk_clause!(missing, pack, expr["denominator"])
        walk_clause!(missing, pack, expr["numerator"])
        check_team_score_expression!(missing, pack, expr)
      end
      missing.uniq
    end

    def check_team_score_expression!(missing, pack, expr)
      mode = expr["team_score_mode"]
      return if mode.blank?

      ref = "#{pack.dig('catalog', 'code')}.#{pack['rule_code']}"
      missing << "#{ref}: team_score_mode #{mode}" if TEAM_SCORE_MODES.exclude?(mode)
      return unless mode == "linkage_aggregate"

      Array(expr["linkage_components"]).each do |component|
        code = component["code"]
        missing << "#{ref}: linkage_components missing code" if code.blank?
        if code.present? && !Portaria3493.known_indicator_code?(code)
          missing << "#{ref}: linkage_components unknown indicator #{code}"
        end
      end

      bonus = expr["linkage_sat_bonus"]
      return unless bonus.is_a?(Hash) && bonus["code"].present? && !bonus["external_until_import"]

      bonus_code = bonus["code"]
      return if Portaria3493.known_indicator_code?(bonus_code)

      missing << "#{ref}: linkage_sat_bonus unknown indicator #{bonus_code}"
    end

    def full_report
      packs = MethodologyPackDefinitions.all
      db_rules = IndicatorRule
        .includes(:indicator_catalog)
        .joins(:indicator_catalog)
        .where(indicator_catalog: RuleCatalog.active_portaria_attributes)
        .to_a
      db_by_code = db_rules.group_by { |r| r.indicator_catalog.code }
      pack_by_code = packs.group_by { |p| p.dig("catalog", "code") }
      disk = load_disk_packs
      disk_packs = disk.fetch(:valid)
      pack_drift = pack_drift_report(packs, disk_packs) + disk.fetch(:invalid)
      unreadable = disk.fetch(:unreadable)
      pack_drift << "unreadable_on_disk: #{unreadable.join(', ')}" if unreadable.any?

      {
        "packs_defined" => packs.size,
        "packs_on_disk" => disk_packs.size,
        "pack_drift" => pack_drift,
        "rules_in_db" => db_rules.size,
        "packs_unreadable_on_disk" => unreadable.size,
        "catalogs_in_db" => IndicatorCatalog.active_portaria.count,
        "bp_coverage" => bp_coverage_summary(pack_by_code, db_by_code),
        "resolver_types" => resolver_types,
        "missing_resolvers" => missing_resolvers_for(packs),
        "pni_calendar" => pni_calendar_summary,
        "matrix_path" => Rails.root.join("docs/indicators/methodology-coverage-matrix.md").to_s,
        "matrix_status" => matrix_status_summary
      }
    end

    def matrix_status_summary(path = Rails.root.join("docs/indicators/methodology-coverage-matrix.md"))
      return {} unless path.exist?

      lines = path.read.lines
      start_idx = lines.index { |line| line.start_with?("## Component II") } || 0
      counts = Hash.new(0)

      lines[start_idx..].each do |line|
        next unless line.strip.start_with?("|")
        next if line.include?("---|")
        next if line.include?("Significado") || line.include?("Resumo numerador")

        cells = line.split("|").map(&:strip)
        next if cells.size < 4

        status_cell = cells.reverse.find { |cell| cell.match?(/\A(done|partial|external|todo)\b/i) }
        next unless status_cell

        match = status_cell.match(/\A(done|partial|external|todo)\b/i)

        counts[match[1].downcase] += 1
      end

      total = counts.values.sum
      done = counts["done"]
      summary = {
        "done" => done,
        "partial" => counts["partial"],
        "external" => counts["external"],
        "todo" => counts["todo"],
        "total" => total,
        "done_pct" => total.positive? ? ((done.to_f / total) * 100).round(1) : 0.0
      }
      summary["expected_total"] = EXPECTED_MATRIX_ROWS
      summary["total_mismatch"] = true if total.positive? && total != EXPECTED_MATRIX_ROWS
      summary
    end

    def load_disk_packs
      dir = MethodologyPackLoader::PACKS_DIR
      return { valid: [], invalid: [], unreadable: [] } unless dir.exist?

      valid = []
      invalid = []
      unreadable = []
      dir.glob("*.json").each do |path|
        valid << JSON.parse(path.read)
      rescue JSON::ParserError => error
        invalid << "invalid_json: #{path.basename}(#{error.message})"
        unreadable << path.basename.to_s
      rescue StandardError => error
        invalid << "unreadable: #{path.basename}(#{error.message})"
        unreadable << path.basename.to_s
      end
      { valid: valid, invalid: invalid, unreadable: unreadable }
    end

    def pack_drift_report(definitions, disk_packs)
      if disk_packs.empty?
        return [] if definitions.empty?

        return [ "missing_on_disk: all (#{definitions.size} packs expected)" ]
      end

      definition_keys = definitions.map { |pack| pack_key(pack) }.sort
      disk_keys = disk_packs.map { |pack| pack_key(pack) }.sort
      missing_on_disk = definition_keys - disk_keys
      extra_on_disk = disk_keys - definition_keys

      definition_by_key = definitions.index_by { |pack| pack_key(pack) }
      disk_by_key = disk_packs.index_by { |pack| pack_key(pack) }

      drift = []
      drift << "missing_on_disk: #{missing_on_disk.join(', ')}" if missing_on_disk.any?
      drift << "extra_on_disk: #{extra_on_disk.join(', ')}" if extra_on_disk.any?

      content_drift = (definition_keys & disk_keys).filter_map do |key|
        key unless pack_comparable_payload(definition_by_key[key]) == pack_comparable_payload(disk_by_key[key])
      end
      drift << "content_drift: #{content_drift.join(', ')}" if content_drift.any?

      drift
    end

    def pack_comparable_payload(pack)
      pack.deep_stringify_keys.slice(
        "catalog", "rule_code", "good_practice_code", "expression",
        "source_ref", "numerator_summary", "denominator_summary", "record_types"
      )
    end

    def pack_key(pack)
      "#{pack.dig('catalog', 'code')}.#{pack.fetch('rule_code')}"
    end

    def pack_files_count
      load_disk_packs.fetch(:valid).size
    end

    def bp_coverage_summary(pack_by_code, db_by_code)
      Portaria3493::INDICATOR_CODES.filter_map do |code|
        pack_rules = pack_by_code[code] || []
        db_rules = db_by_code[code] || []
        expected = pack_rules.size
        actual = db_rules.size
        next if expected.zero? && actual.zero?

        orphan_db_rules = db_rules.map(&:rule_code) - pack_rules.map { |pack| pack.fetch("rule_code") }
        expression_drift = pack_rules.filter_map do |pack|
          db_rule = db_rules.find { |rule| rule.rule_code == pack.fetch("rule_code") }
          next pack.fetch("rule_code") if db_rule.blank?
          next pack.fetch("rule_code") unless db_expression_matches_pack?(db_rule, pack)

          nil
        end

        aligned = expected == actual && orphan_db_rules.empty? && expression_drift.empty?

        {
          "indicator" => code,
          "pack_rules" => expected,
          "db_rules" => actual,
          "orphan_db_rules" => orphan_db_rules,
          "expression_drift" => expression_drift,
          "aligned" => aligned
        }
      end
    end

    def db_expression_matches_pack?(db_rule, pack)
      code = pack.dig("catalog", "code")
      expected = MethodologyPackLoader.build_expression(code: code, pack: pack)
      normalize_expression(db_rule.expression) == normalize_expression(expected)
    end

    def normalize_expression(expression)
      JSON.parse(JSON.generate(expression.deep_stringify_keys))
    end

    def misaligned_bp_coverage(report)
      Array(report["bp_coverage"]).reject { |row| row["aligned"] }
    end

    def format_bp_misalignment(row)
      parts = [ "#{row['indicator']}(pack=#{row['pack_rules']},db=#{row['db_rules']})" ]
      parts << "orphans=#{row['orphan_db_rules'].join('|')}" if row["orphan_db_rules"].present?
      parts << "expression_drift=#{row['expression_drift'].join('|')}" if row["expression_drift"].present?
      parts.join(" ")
    end

    def walk_clause!(missing, pack, clause)
      return if clause.blank?

      case clause
      when Hash
        if clause["type"].present?
          check_clause_type!(missing, pack, clause)
        else
          clause.each_value { |value| walk_clause!(missing, pack, value) }
        end
      when Array
        clause.each { |item| walk_clause!(missing, pack, item) }
      end
    end

    def check_clause_type!(missing, pack, clause)
      type = clause["type"]
      ref = "#{pack.dig('catalog', 'code')}.#{pack['rule_code']}"
      if type == "all"
        Array(clause["clauses"]).each { |sub| walk_clause!(missing, pack, sub) }
        return
      end
      unless CITIZEN_SCOPE_TYPES.include?(type) || CLINICAL_EVIDENCE_TYPES.include?(type)
        missing << "#{ref}: unknown clause type #{type}"
        return
      end

      validate_gestational_evidence_clause!(missing, ref, clause) if type == "gestational_evidence_count_gte"
    end

    def pni_calendar_summary
      return { "available" => false } unless PniScheduleEntry.table_exists?

      Reference::PniCalendarLoader.audit_report.transform_keys(&:to_s).merge("available" => true)
    rescue StandardError => error
      { "available" => false, "error" => error.message }
    end

    def validate_gestational_evidence_clause!(missing, ref, clause)
      measure = clause["measure"].to_s
      allowed = DslV1::Resolvers::GestationalAnchor::GESTATIONAL_EVIDENCE_MEASURES
      unless allowed.include?(measure)
        missing << "#{ref}: gestational_evidence_count_gte unknown measure #{measure.inspect}"
      end

      return unless %w[consult visit].include?(measure)
      return if clause["predicate"].present?

      missing << "#{ref}: gestational_evidence_count_gte measure #{measure} requires predicate"
    end
    private_class_method :validate_gestational_evidence_clause!
  end
end
