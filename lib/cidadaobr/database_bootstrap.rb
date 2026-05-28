# frozen_string_literal: true

module Cidadaobr
  module DatabaseBootstrap
    module_function

    def ensure_admin_objects!(env: ActiveRecord::Tasks::DatabaseTasks.env || Rails.env)
      config = ActiveRecord::Base.configurations.find_db_config(env.to_s)
      return unless config

      admin_config = config.configuration_hash.merge(
        username: ENV.fetch("POSTGRES_SCHEMA_USER", "postgres"),
        password: ENV.fetch("POSTGRES_SCHEMA_PASSWORD", "postgres")
      )

      ActiveRecord::Base.establish_connection(admin_config)
      TenantRlsPolicies.ensure!
      DatabaseRoleSetup.ensure!
    ensure
      ActiveRecord::Base.establish_connection(config)
    end
  end
end
