require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module InventoryApp
  class Application < Rails::Application
    config.load_defaults 8.0

    config.i18n.available_locales = %i[en uz]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [:en]

    config.time_zone = "UTC"
    config.generators.system_tests = nil
  end
end
