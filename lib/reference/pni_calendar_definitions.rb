# frozen_string_literal: true

module Reference
  # Normative PNI calendar definitions (SOT). JSON under lib/reference/pni/ is export-only.
  module PniCalendarDefinitions
    SOURCE_REF = "https://www.gov.br/saude/pt-br/vacinacao/calendario-tecnico/calendario-tecnico-nacional-de-vacinacao-crianca".freeze

    module_function

    def all
      [ child_0_2_2026 ]
    end

    def child_0_2_2026
      {
        "export" => export_metadata,
        "calendar" => {
          "year" => 2026,
          "age_group" => "child",
          "scope" => "0_2",
          "scope_label" => "0-24 months (C2.E)",
          "effective_from" => "2026-01-01",
          "effective_until" => nil,
          "source_ref" => SOURCE_REF
        },
        "entries" => child_0_2_entries
      }
    end

    def child_0_2_entries
      [
        entry("15", "BCG", "1", "D1", 0, 30, aliases: %w[bcg]),
        entry("45", "Hepatite B", "1", "D1", 0, 30, aliases: %w[hepb hepatite b]),
        entry("29", "Pentavalente", "1", "D1", 60, 90, aliases: %w[penta pentavalente]),
        entry("29", "Pentavalente", "2", "D2", 120, 150, aliases: %w[penta pentavalente]),
        entry("29", "Pentavalente", "3", "D3", 180, 210, aliases: %w[penta pentavalente]),
        entry("29", "Pentavalente", "R1", "R1", 450, 540, aliases: %w[penta pentavalente]),
        entry("22", "VIP", "1", "D1", 60, 90, aliases: %w[vip poliomielite]),
        entry("22", "VIP", "2", "D2", 120, 150, aliases: %w[vip poliomielite]),
        entry("22", "VIP", "3", "D3", 180, 210, aliases: %w[vip poliomielite]),
        entry("22", "VIP", "R1", "R1", 450, 540, aliases: %w[vip poliomielite]),
        entry("43", "Rotavírus", "1", "D1", 60, 120, aliases: %w[rotavirus rotavírus]),
        entry("43", "Rotavírus", "2", "D2", 120, 240, aliases: %w[rotavirus rotavírus]),
        entry("26", "Pneumocócica 10", "1", "D1", 60, 90, aliases: %w[pneumo pneumococica]),
        entry("26", "Pneumocócica 10", "2", "D2", 120, 150, aliases: %w[pneumo pneumococica]),
        entry("26", "Pneumocócica 10", "3", "R1", 365, 450, aliases: %w[pneumo pneumococica]),
        entry("41", "Meningocócica C", "1", "D1", 90, 120, aliases: %w[meningo meningococica]),
        entry("41", "Meningocócica C", "2", "D2", 150, 180, aliases: %w[meningo meningococica]),
        entry("14", "Febre Amarela", "1", "D1", 270, 330, aliases: %w[febre amarela]),
        entry("24", "SCR", "1", "D1", 365, 450, aliases: %w[scr mmr tríplice viral triple viral]),
        entry("83", "Hepatite A", "1", "D1", 450, 540, aliases: %w[hepatite a]),
        entry("56", "Tetra viral", "1", "D1", 450, 540, aliases: %w[tetra viral])
      ]
    end

    def export_metadata
      {
        "role" => "audit_trail_only",
        "source_of_truth" => "lib/reference/pni_calendar_definitions.rb",
        "note" => "Export-only audit trail. SyncPniCalendar loads Reference::PniCalendarDefinitions (Ruby), not this JSON. reference:pni:audit reads this file to compare disk vs DB."
      }
    end

    def entry(code, name, dose_code, dose_label, min_age_days, max_age_days, aliases: [], strategy: "routine")
      {
        "immunobiological_code" => code,
        "immunobiological_name" => name,
        "dose_code" => dose_code,
        "dose_label" => dose_label,
        "min_age_days" => min_age_days,
        "max_age_days" => max_age_days,
        "strategy" => strategy,
        "aliases" => aliases
      }
    end
  end
end
