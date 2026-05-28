# frozen_string_literal: true

class ApplicationCommand
  def self.call(**kwargs)
    new(**kwargs).call
  end
end
