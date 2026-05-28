# frozen_string_literal: true

module Cidadaobr
  module SchemaMigrationConnection
    module_function

    def schema_credentials
      {
        username: ENV.fetch("POSTGRES_SCHEMA_USER", "postgres"),
        password: ENV.fetch("POSTGRES_SCHEMA_PASSWORD", "postgres")
      }
    end

    def use_schema_user!(env: ActiveRecord::Tasks::DatabaseTasks.env || Rails.env)
      config = ActiveRecord::Base.configurations.find_db_config(env.to_s)
      return false unless config

      current = config.configuration_hash
      schema_user = schema_credentials[:username]
      return false if current[:username].to_s == schema_user.to_s

      ActiveRecord::Base.establish_connection(current.merge(schema_credentials))
      true
    end

    def restore_app_connection!(env: ActiveRecord::Tasks::DatabaseTasks.env || Rails.env)
      config = ActiveRecord::Base.configurations.find_db_config(env.to_s)
      return unless config

      ActiveRecord::Base.establish_connection(config)
    end
  end
end
