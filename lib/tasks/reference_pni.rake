# frozen_string_literal: true

namespace :reference do
  namespace :pni do
    desc "Sync PNI calendar definitions to DB and export JSON audit trail (no release publish)"
    task sync: :environment do
      # Release cut: dispatch SyncPniCalendar with publish_release: true, then audit, then recalculate_indicators.
      result = CommandBus.dispatch(Reference::Commands::SyncPniCalendar, export_json: true)
      puts JSON.pretty_generate(result)
    end

    desc "Export PNI calendar JSON files without DB sync"
    task export: :environment do
      Reference::PniCalendarLoader.ensure_json_export!
      count = Reference::PniCalendarLoader::PNI_DIR.glob("*/*.json").count
      puts "Exported #{count} calendar file(s) to #{Reference::PniCalendarLoader::PNI_DIR}"
    end

    desc "Audit PNI calendar Ruby definitions vs JSON export vs DB"
    task audit: :environment do
      report = Reference::PniCalendarLoader.audit_report
      puts JSON.pretty_generate(report)

      exit_code = 0
      if report[:calendars_unreadable_on_disk].to_i.positive?
        warn "Unreadable calendar files on disk: #{report[:calendars_unreadable_on_disk]}"
        exit_code = 1
      end

      if report[:calendars_defined] != report[:calendars_on_disk]
        warn "Calendar file count mismatch: defined=#{report[:calendars_defined]}, on_disk=#{report[:calendars_on_disk]}"
        exit_code = 1
      end

      if report[:entries_defined] != report[:entries_on_disk]
        warn "Entry count mismatch (disk): defined=#{report[:entries_defined]}, on_disk=#{report[:entries_on_disk]}"
        exit_code = 1
      end

      if report[:entries_defined] != report[:entries_in_db]
        warn "Entry count mismatch (db): defined=#{report[:entries_defined]}, in_db=#{report[:entries_in_db]}"
        exit_code = 1
      end

      if report[:drift].any?
        warn "Calendar drift: #{report[:drift].join('; ')}"
        exit_code = 1
      end

      exit exit_code if exit_code.nonzero?
    end

    desc "Recalculate team C2 scores after PNI calendar release (async, one job per municipality)"
    task recalculate_indicators: :environment do
      # Release cut: sync with publish_release: true, audit, then this task (jobs run in background).
      result = CommandBus.dispatch(Indicators::RecalculateForPniRelease)
      puts JSON.pretty_generate(result)
      warn "PNI recalculation jobs enqueued — C2 scores update async; ensure the job worker is running."
      warn "Idempotent: do not re-run until jobs finish; each run enqueues one job per municipality."
    end
  end
end
