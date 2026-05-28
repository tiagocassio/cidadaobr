# frozen_string_literal: true

Rake::Task["db:prepare"].enhance do
  Cidadaobr::DatabaseBootstrap.ensure_admin_objects!
end

Rake::Task["db:schema:load"].enhance do
  Cidadaobr::DatabaseBootstrap.ensure_admin_objects!
end
