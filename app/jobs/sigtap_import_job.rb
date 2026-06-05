# frozen_string_literal: true

class SigtapImportJob < ApplicationJob
  queue_as :default

  def perform(competence: Date.current.strftime("%Y%m"))
    CommandBus.dispatch(Reference::Commands::ImportSigtap, competence: competence)
  end
end
