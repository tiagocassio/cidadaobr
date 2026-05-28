# frozen_string_literal: true

class ApplicationQuery
  def self.call(**kwargs)
    new(**kwargs).call
  end
end
