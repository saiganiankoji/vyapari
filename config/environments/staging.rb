require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  
  # Enable serving static files for staging (since no NGINX)
  config.public_file_server.enabled = true
  
  # Assets
  config.assets.compile = false
  
  # Storage
  config.active_storage.service = :local
  
  # SSL - disable for now, enable later if needed
  config.force_ssl = false
  
  # Logging
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }
  
  config.log_tags = [ :request_id ]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  
  # Mailer settings for staging
  config.action_mailer.default_url_options = { host: "your-app.onrender.com" }
  config.action_mailer.perform_caching = false
  
  # Allow your staging domain
  config.hosts << "your-app.onrender.com"
  config.hosts << "staging.aruna_solar.com" # if you plan to use custom domain
  
  # Other settings
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]
end