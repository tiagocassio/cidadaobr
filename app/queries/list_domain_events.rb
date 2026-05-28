# frozen_string_literal: true

class ListDomainEvents < ApplicationQuery
  def initialize(limit: 50)
    @limit = limit
  end

  def call
    DomainEvent.order(occurred_at: :desc).limit(@limit)
  end
end
