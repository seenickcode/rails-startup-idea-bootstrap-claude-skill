# Fail fast at boot rather than at first use. No fallback values.
# Skipped during Docker asset precompile (SECRET_KEY_BASE_DUMMY).
unless ENV["SECRET_KEY_BASE_DUMMY"]
  if Rails.env.production?
    %w[APP_HOST POSTMARK_API_TOKEN ADMIN_EMAIL POSTHOG_API_KEY
       STRIPE_SECRET_KEY STRIPE_WEBHOOK_SECRET SENDER_API_TOKEN].each do |var|
      raise "Missing required env var: #{var}" if ENV[var].blank?
    end
  end
end
