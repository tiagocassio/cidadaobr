# frozen_string_literal: true

class PniCalendarImportJob < ApplicationJob
  queue_as :default

  def perform(export_json: true, publish_release: false)
    CommandBus.dispatch(
      Reference::Commands::ImportPniCalendar,
      export_json: export_json,
      publish_release: publish_release,
      job_name: self.class.name
    )
  end
end
