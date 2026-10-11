# Server-side PostHog client, production-only. Fail fast: no silent
# analytics blackholes.
# The posthog-ruby gem's lib file is posthog.rb, so Bundler's autorequire
# under the gem name never loads it — require it explicitly.
require "posthog"
unless ENV["SECRET_KEY_BASE_DUMMY"]
  if Rails.env.production?
    key = ENV["POSTHOG_API_KEY"]
    raise "POSTHOG_API_KEY is required in production" if key.blank?
    $posthog = PostHog::Client.new(
      api_key: key,
      host: ENV.fetch("POSTHOG_HOST", "https://eu.i.posthog.com"),
      on_error: ->(status, msg) { Rails.logger.error("PostHog: #{status} #{msg}") }
    )
  end
end
