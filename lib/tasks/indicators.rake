# frozen_string_literal: true

namespace :indicators do
  desc "Audit methodology pack coverage vs DB rules and resolver types"
  task audit_coverage: :environment do
    report = Indicators::CoverageAudit.full_report
    puts JSON.pretty_generate(report)

    exit_code = 0

    if report["missing_resolvers"].any?
      warn "Missing resolver types: #{report['missing_resolvers'].join(', ')}"
      exit_code = 1
    end

    if report["packs_on_disk"] != report["packs_defined"]
      warn "Pack file count mismatch: defined=#{report['packs_defined']}, on_disk=#{report['packs_on_disk']}"
      exit_code = 1
    end

    if report["packs_unreadable_on_disk"].to_i.positive?
      warn "Unreadable pack files on disk: #{report['packs_unreadable_on_disk']}"
      exit_code = 1
    end

    if report["pack_drift"].any?
      warn "Pack drift: #{report['pack_drift'].join('; ')}"
      exit_code = 1
    end

    misaligned = Indicators::CoverageAudit.misaligned_bp_coverage(report)
    if misaligned.any?
      warn "BP coverage misaligned: #{misaligned.map { |row| Indicators::CoverageAudit.format_bp_misalignment(row) }.join(', ')}"
      exit_code = 1
    end

    exit exit_code if exit_code.nonzero?
  end

  namespace :catalog do
    desc "Seed Portaria 3.493 indicator catalog (CVAT, V-*, C1–C7, B1–B6, M1–M2)"
    task seed: :environment do
      load Rails.root.join("db/seeds/indicator_catalog.rb")
    end

    desc "Export methodology packs to lib/indicators/methodology/3493-2024/packs/*.json"
    task export_packs: :environment do
      Indicators::MethodologyPackLoader.ensure_pack_json_export!
      count = Indicators::MethodologyPackLoader::PACKS_DIR.glob("*.json").count
      puts "Exported #{count} pack file(s) to #{Indicators::MethodologyPackLoader::PACKS_DIR}"
    end
  end

  namespace :gaps do
    desc "Detect citizen indicator gaps (prefer CITIZEN_ID or CARE_TEAM_ID; optional INDICATOR_CODES)"
    task detect: :environment do
      tenant = Cidadaobr::TenantContext.current_or_raise!
      if Rails.env.production? && ENV["CITIZEN_ID"].blank? && ENV["CARE_TEAM_ID"].blank?
        abort "Set CITIZEN_ID or CARE_TEAM_ID in production to avoid scanning the whole municipality"
      end

      puts "Detecting gaps for municipality #{tenant.municipality_id}..."

      result = Indicators::DetectCitizenGaps.call(
        citizen_id: ENV["CITIZEN_ID"],
        care_team_id: ENV["CARE_TEAM_ID"],
        indicator_codes: ENV["INDICATOR_CODES"]&.split(",")
      )
      puts result.inspect
    end
  end

  namespace :teams do
    desc "Recalculate team indicator scores (requires CARE_TEAM_ID, optional QUADRIMESTER, INDICATOR_CODES)"
    task recalculate: :environment do
      care_team_id = ENV.fetch("CARE_TEAM_ID")
      tenant = Cidadaobr::TenantContext.current_or_raise!
      puts "Recalculating scores for team #{care_team_id} in municipality #{tenant.municipality_id}..."

      results = Indicators::RecalculateTeamScore.call(
        care_team_id: care_team_id,
        quadrimester: ENV["QUADRIMESTER"],
        indicator_codes: ENV["INDICATOR_CODES"]&.split(",")
      )
      puts "Updated #{results.size} team indicator result(s)"
    end
  end
end
