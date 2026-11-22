Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # The app is expected to run behind a TLS-terminating proxy. Set FORCE_SSL=false to disable.
  config.assume_ssl = ENV["FORCE_SSL"] != "false"
  config.force_ssl = ENV["FORCE_SSL"] != "false"

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
  config.i18n.fallbacks = [:en]
end
