# frozen_string_literal: true

class QueryBus
  def self.ask(query_class, **kwargs)
    query_class.call(**kwargs)
  end
end
