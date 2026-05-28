# frozen_string_literal: true

module Ledi
  module Errors
    class EmptyBatchError < StandardError; end
    class ImmutableTransportRecordError < StandardError; end
    class UnknownCareTeamError < StandardError; end
    class AmbiguousTeamScopeError < StandardError; end
    class MissingClinicalRecordError < StandardError; end
  end
end
