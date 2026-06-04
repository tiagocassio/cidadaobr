# frozen_string_literal: true

module Reference
  module Commands
    class SyncPniCalendar < ApplicationCommand
      def initialize(export_json: false, publish_release: false)
        @export_json = export_json
        @publish_release = publish_release
      end

      def call
        calendars = PniCalendarLoader.load_calendars
        active_entry_keys = []

        write_transaction do
          calendars.each do |calendar|
            calendar_meta = calendar.fetch("calendar")
            upsert_entries!(calendar_meta, calendar.fetch("entries"), active_entry_keys)
          end

          prune_stale_entries!(active_entry_keys)
        end

        if @export_json
          # DB commits in write_transaction above; export runs after. Re-run sync if export fails post-commit.
          begin
            PniCalendarLoader.ensure_json_export!
          rescue StandardError => error
            raise "SyncPniCalendar: DB synced but JSON export failed — #{error.message}", cause: error
          end
        end

        CommandBus.dispatch(Reference::Commands::PublishRelease) if @publish_release

        {
          calendars: calendars.size,
          entries: PniScheduleEntry.active.count,
          pni_dir: PniCalendarLoader::PNI_DIR.to_s
        }
      end

      private

      def upsert_entries!(calendar_meta, schedule_entries, active_entry_keys)
        year = calendar_meta.fetch("year")
        age_group = calendar_meta.fetch("age_group")
        effective_from = Date.parse(calendar_meta.fetch("effective_from"))
        effective_until = calendar_meta["effective_until"].present? ? Date.parse(calendar_meta.fetch("effective_until")) : nil

        schedule_entries.each do |schedule_entry|
          validate_schedule_entry!(calendar_meta, schedule_entry, effective_from: effective_from, effective_until: effective_until)
        end

        synced_at = Time.current
        rows = schedule_entries.map do |schedule_entry|
          code = schedule_entry.fetch("immunobiological_code")
          dose = schedule_entry.fetch("dose_code")
          active_entry_keys << [ year, age_group, code, dose ]

          {
            calendar_year: year,
            age_group: age_group,
            effective_from: effective_from,
            effective_until: effective_until,
            immunobiological_code: code,
            dose_code: dose,
            immunobiological_name: schedule_entry.fetch("immunobiological_name"),
            dose_label: schedule_entry["dose_label"],
            min_age_days: schedule_entry.fetch("min_age_days"),
            max_age_days: schedule_entry.fetch("max_age_days"),
            strategy: schedule_entry["strategy"],
            aliases: Array(schedule_entry["aliases"]),
            active: true
          }
        end
        return if rows.empty?

        existing_ids = existing_entry_ids(year: year, age_group: age_group, rows: rows)

        # record_timestamps sets created_at/updated_at on INSERT; upsert_all does not bump updated_at
        # on conflict, so touch_synced_entries! updates updated_at only for rows that already existed.
        PniScheduleEntry.upsert_all(
          rows,
          unique_by: :index_pni_schedule_entries_on_year_age_group_code_dose,
          update_only: %i[
            effective_from effective_until immunobiological_name dose_label min_age_days max_age_days
            strategy aliases active
          ],
          record_timestamps: true
        )
        touch_synced_entries!(ids: existing_ids, synced_at: synced_at)
      end

      def existing_entry_ids(year:, age_group:, rows:)
        pairs = rows.map { |row| [ row[:immunobiological_code], row[:dose_code] ] }
        tuple_sql = pairs.map { "(?, ?)" }.join(", ")
        PniScheduleEntry.where(calendar_year: year, age_group: age_group)
          .where("(immunobiological_code, dose_code) IN (#{tuple_sql})", *pairs.flatten)
          .pluck(:id)
      end

      def touch_synced_entries!(ids:, synced_at:)
        return if ids.empty?

        PniScheduleEntry.where(id: ids).update_all(updated_at: synced_at)
      end

      def validate_schedule_entry!(calendar_meta, schedule_entry, effective_from:, effective_until:)
        record = PniScheduleEntry.new(
          calendar_year: calendar_meta.fetch("year"),
          age_group: calendar_meta.fetch("age_group"),
          effective_from: effective_from,
          effective_until: effective_until,
          immunobiological_code: schedule_entry.fetch("immunobiological_code"),
          dose_code: schedule_entry.fetch("dose_code"),
          immunobiological_name: schedule_entry.fetch("immunobiological_name"),
          dose_label: schedule_entry["dose_label"],
          min_age_days: schedule_entry.fetch("min_age_days"),
          max_age_days: schedule_entry.fetch("max_age_days"),
          strategy: schedule_entry["strategy"],
          aliases: Array(schedule_entry["aliases"]),
          active: true
        )
        return if record.valid?

        raise ArgumentError,
              "SyncPniCalendar: invalid entry #{schedule_entry.fetch('immunobiological_code')}/#{schedule_entry.fetch('dose_code')}: #{record.errors.full_messages.to_sentence}"
      end

      def prune_stale_entries!(active_entry_keys)
        synced_at = Time.current
        return deactivate_all_active_entries!(synced_at) if active_entry_keys.empty?

        placeholders = active_entry_keys.map { "(?, ?, ?, ?)" }.join(", ")
        binds = active_entry_keys.flat_map { |year, age_group, code, dose| [ year, age_group, code, dose ] }
        sql = <<~SQL.squish
          UPDATE pni_schedule_entries
          SET active = false, updated_at = ?
          WHERE active = true
            AND (calendar_year, age_group, immunobiological_code, dose_code) NOT IN (#{placeholders})
        SQL

        PniScheduleEntry.connection.exec_update(
          ActiveRecord::Base.sanitize_sql_array([ sql, synced_at, *binds ])
        )
      end

      def deactivate_all_active_entries!(synced_at)
        PniScheduleEntry.active.update_all(active: false, updated_at: synced_at)
      end
    end
  end
end
