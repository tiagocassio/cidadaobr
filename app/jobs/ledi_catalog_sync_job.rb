# frozen_string_literal: true

class LediCatalogSyncJob < ApplicationJob
  queue_as :default

  def perform
    CommandBus.dispatch(Reference::Commands::SyncLediCatalog)
  end
end
