# frozen_string_literal: true

module Web
  class DashboardController < BaseController
    def show
      @events = QueryBus.ask(ListDomainEvents, limit: 10)
      @stats = {
        health_facilities: scoped_health_facilities.count,
        care_teams: scoped_care_teams.count,
        citizens: scoped_citizens.count,
        households: scoped_households.count,
        ledi_batches: scoped_ledi_batches.group(:status).count
      }
    end
  end
end
