# frozen_string_literal: true

namespace :cidadaobr do
  namespace :db do
    task with_schema_user: :environment do
      Cidadaobr::SchemaMigrationConnection.use_schema_user!
    end
  end
end

SCHEMA_MUTATION_TASKS = %w[
  db:migrate
  db:rollback
  db:migrate:up
  db:migrate:down
  db:migrate:redo
  db:schema:load
].freeze

SCHEMA_MUTATION_TASKS.each do |task_name|
  Rake::Task[task_name].enhance(["cidadaobr:db:with_schema_user"])
  Rake::Task[task_name].enhance do
    Cidadaobr::DatabaseBootstrap.ensure_admin_objects!
  ensure
    Cidadaobr::SchemaMigrationConnection.restore_app_connection!
  end
end

Rake::Task["db:prepare"].enhance(["cidadaobr:db:with_schema_user"])
Rake::Task["db:prepare"].enhance do
  Cidadaobr::DatabaseBootstrap.ensure_admin_objects!
ensure
  Cidadaobr::SchemaMigrationConnection.restore_app_connection!
end
