# frozen_string_literal: true

module Cidadaobr
  module Errors
    class MissingTenantScope < StandardError; end
    class Unauthorized < StandardError; end
  end
end
