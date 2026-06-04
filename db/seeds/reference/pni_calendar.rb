# frozen_string_literal: true

if PniScheduleEntry.table_exists?
  result = CommandBus.dispatch(Reference::Commands::SyncPniCalendar, export_json: true, publish_release: false)
  Rails.logger.info(
    "[reference/pni] synced #{result[:calendars]} calendar(s), #{result[:entries]} entries from #{result[:pni_dir]}"
  )
end
