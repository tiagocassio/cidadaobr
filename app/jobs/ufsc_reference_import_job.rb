# frozen_string_literal: true

class UfscReferenceImportJob < ApplicationJob
  queue_as :default

  def perform
    CommandBus.dispatch(
      Reference::Commands::ImportDomains,
      source: "reference_seed",
      domain_keys: %w[ciap2 cid10]
    )
  end
end
