# Postmark over its HTTPS API — NOT SMTP. Container egress on the VPS is
# restricted to :80/:443, so SMTP on :587 times out from inside a container
# and fails silently in background jobs. Don't switch this back to SMTP.
unless ENV["SECRET_KEY_BASE_DUMMY"]
  if Rails.env.production?
    # Initializers run after environments/*, so guard or this clobbers
    # letter_opener_web in development.
    ActionMailer::Base.delivery_method = :postmark
    ActionMailer::Base.postmark_settings = { api_token: ENV.fetch("POSTMARK_API_TOKEN") }
    host = ENV.fetch("APP_HOST")
    ActionMailer::Base.default_url_options = { host:, protocol: "https" }
    ActionMailer::Base.asset_host = "https://#{host}"
  end
end
