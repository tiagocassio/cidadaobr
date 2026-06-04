# frozen_string_literal: true

module Reference
  module PniCalendarLoader
    PNI_DIR = Rails.root.join("lib/reference/pni").freeze

    module_function

    def load_calendars
      PniCalendarDefinitions.all
    end

    def ensure_json_export!
      calendars = load_calendars
      expected_paths = calendars.map { |calendar| export_path_for(calendar) }
      staging = PNI_DIR.join(".export-staging-#{Process.pid}")
      FileUtils.mkdir_p(staging)

      calendars.each do |calendar|
        destination = export_path_for(calendar)
        path = staging.join(destination.relative_path_from(PNI_DIR))
        FileUtils.mkdir_p(path.dirname)
        path.write("#{JSON.pretty_generate(calendar)}\n")
      end

      staging.glob("**/*.json").each do |path|
        destination = PNI_DIR.join(path.relative_path_from(staging))
        FileUtils.mkdir_p(destination.dirname)
        FileUtils.mv(path, destination, force: true)
      end

      expected_paths.each do |path|
        next if path.exist?

        raise "Missing exported calendar file: #{path}"
      end

      prune_orphan_exports!(expected_paths)
    ensure
      FileUtils.rm_rf(staging) if staging && Dir.exist?(staging)
    end

    def export_path_for(calendar)
      calendar_meta = calendar.fetch("calendar")
      year = calendar_meta.fetch("year")
      age_group = calendar_meta.fetch("age_group")
      scope = calendar_meta.fetch("scope")
      PNI_DIR.join(year.to_s, "#{age_group}.#{scope}.json")
    end

    def prune_orphan_exports!(expected_paths)
      PNI_DIR.glob("*/*.json").each do |path|
        FileUtils.rm_f(path) unless expected_paths.include?(path)
      end

      PNI_DIR.glob("*.json").each do |path|
        FileUtils.rm_f(path)
      end
    end

    def audit_report
      calendars = load_calendars
      defined_entries = calendars.sum { |calendar| calendar.fetch("entries").size }
      disk = load_disk_calendars
      db_entries = PniScheduleEntry.active.count

      {
        calendars_defined: calendars.size,
        entries_defined: defined_entries,
        calendars_on_disk: disk.fetch(:valid).size,
        entries_on_disk: disk.fetch(:valid).sum { |calendar| calendar.fetch("entries").size },
        calendars_unreadable_on_disk: disk.fetch(:unreadable).size,
        entries_in_db: db_entries,
        drift: calendar_drift(calendars, disk.fetch(:valid), db_entries)
      }
    end

    def load_disk_calendars
      valid = []
      unreadable = []

      PNI_DIR.glob("*/*.json").each do |path|
        valid << JSON.parse(path.read)
      rescue JSON::ParserError, Errno::ENOENT
        unreadable << path.to_s
      end

      { valid: valid, unreadable: unreadable }
    end

    def calendar_drift(definitions, disk_calendars, db_entries)
      issues = []
      defined_entries = definitions.sum { |calendar| calendar.fetch("entries").size }
      disk_entries = disk_calendars.sum { |calendar| calendar.fetch("entries").size }

      issues << "entries_defined=#{defined_entries} entries_on_disk=#{disk_entries}" if defined_entries != disk_entries
      issues << "entries_defined=#{defined_entries} entries_in_db=#{db_entries}" if defined_entries != db_entries
      issues
    end
  end
end
