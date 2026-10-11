# Sentry — error tracking only, tuned to stay inside the free tier.
# Inactive when SENTRY_DSN is unset; monitoring is optional.
if defined?(Sentry) && ENV["SENTRY_DSN"].present? && Rails.env.production?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = Rails.env

    # Deploy attribution: errors point at the commit that shipped them.
    revision_file = Rails.root.join("REVISION")
    config.release = File.read(revision_file).strip if File.exist?(revision_file)

    # Error tracking ONLY — tracing/profiling are what burn free-tier quota.
    config.traces_sample_rate = 0.0
    config.profiles_sample_rate = 0.0

    # No PII (request bodies, user ids, cookies) in events.
    config.send_default_pii = false

    # Scanner/bot noise on a public site — not app bugs. Sentry's defaults
    # already exclude most of these; listed explicitly to keep the intent.
    config.excluded_exceptions += [
      "ActionController::RoutingError",
      "ActionController::UnknownFormat",
      "ActionController::UnknownHttpMethod",
      "ActionController::BadRequest",
      "ActionController::InvalidAuthenticityToken",
      "ActionDispatch::Http::MimeNegotiation::InvalidType",
      "ActionDispatch::Http::Parameters::ParseError"
    ]

    # Never report the healthcheck endpoint.
    config.before_send = lambda do |event, _hint|
      return nil if event.transaction == "Rails::HealthController#show"
      event
    end
  end
end
