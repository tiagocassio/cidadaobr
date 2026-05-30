# frozen_string_literal: true

class PublishReferenceReleaseJob < ApplicationJob
  queue_as :default

  def perform
    UfscReferenceImportJob.perform_now unless ReferenceDomainEntry.exists?
    LediCatalogSyncJob.perform_now unless LediFieldCatalog.exists?

    Reference::PublishRelease.call
  end
end
