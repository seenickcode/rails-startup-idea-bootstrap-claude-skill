unless ENV["SECRET_KEY_BASE_DUMMY"]
  Stripe.api_key = ENV["STRIPE_SECRET_KEY"] if ENV["STRIPE_SECRET_KEY"].present?
end
