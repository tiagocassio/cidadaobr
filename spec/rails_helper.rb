# frozen_string_literal: true

require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rspec/rails"

ActiveRecord::Migration.maintain_test_schema!

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  config.before(:suite) do
    Cidadaobr::DatabaseBootstrap.ensure_admin_objects!

    app_config = ActiveRecord::Base.connection_db_config.configuration_hash.merge(
      username: ENV.fetch("POSTGRES_APP_USER", "cidadaobr_app"),
      password: ENV.fetch("POSTGRES_APP_PASSWORD", "cidadaobr_app")
    )
    ActiveRecord::Base.establish_connection(app_config)
  end

  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
end
