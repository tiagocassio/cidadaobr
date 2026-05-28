# frozen_string_literal: true

module Web
  class DashboardController < BaseController
    before_action :authenticate!

    def show
      @events = QueryBus.ask(ListDomainEvents, limit: 10)
    end
  end
end
