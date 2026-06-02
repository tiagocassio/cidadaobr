# frozen_string_literal: true

module Reference
  # @deprecated Prefer Reference::Commands::PublishRelease — kept for jobs and rake callers.
  class PublishRelease
    def self.call(**kwargs)
      Commands::PublishRelease.call(**kwargs)
    end
  end
end
