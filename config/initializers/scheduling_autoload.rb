# frozen_string_literal: true

Rails.autoloaders.main.collapse(Rails.root.join("lib/scheduling/commands"))
Rails.autoloaders.main.collapse(Rails.root.join("lib/scheduling/queries"))
