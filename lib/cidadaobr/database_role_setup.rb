# frozen_string_literal: true

module Cidadaobr
  module DatabaseRoleSetup
    APP_ROLE = "cidadaobr_app"
    # Senha do papel de runtime — não usar POSTGRES_APP_PASSWORD (no bootstrap vira "postgres").
    APP_PASSWORD = ENV.fetch("CIDADAOBR_APP_ROLE_PASSWORD", "cidadaobr_app")

    module_function

    def ensure!(connection: ActiveRecord::Base.connection)
      database = connection.quote_table_name(connection.current_database)
      quoted_password = connection.quote(APP_PASSWORD)

      connection.execute <<~SQL
        DO $$
        BEGIN
          IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '#{APP_ROLE}') THEN
            EXECUTE format(
              'CREATE ROLE #{APP_ROLE} LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS',
              #{quoted_password}
            );
          END IF;
        END
        $$;

        GRANT CONNECT ON DATABASE #{database} TO #{APP_ROLE};
        GRANT USAGE ON SCHEMA public TO #{APP_ROLE};
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO #{APP_ROLE};
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO #{APP_ROLE};
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO #{APP_ROLE};
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO #{APP_ROLE};

        DO $$
        BEGIN
          IF current_user <> '#{APP_ROLE}' AND NOT pg_has_role(current_user, '#{APP_ROLE}', 'member') THEN
            EXECUTE 'GRANT #{APP_ROLE} TO ' || quote_ident(current_user);
          END IF;
        END
        $$;
      SQL
    end
  end
end
