# frozen_string_literal: true

class CommandBus
  def self.dispatch(command_class, **kwargs)
    command_class.call(**kwargs)
  end
end
