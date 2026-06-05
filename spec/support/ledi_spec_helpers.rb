# frozen_string_literal: true

module LediSpecHelpers
  module_function

  def ledi_version
    Rails.application.config.ledi.fetch(:version)
  end
end

RSpec.configure do |config|
  config.include LediSpecHelpers
end
