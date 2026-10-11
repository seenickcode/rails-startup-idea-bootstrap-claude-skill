# One-off Stripe Checkout. STRIPE_PRICE_ID blank => purchasing disabled.
class CheckoutController < ApplicationController
  def create
    price_id = ENV["STRIPE_PRICE_ID"]
    return redirect_to root_path, alert: "Purchasing isn't available yet." if price_id.blank?

    session = Stripe::Checkout::Session.create(
      mode: "payment",
      line_items: [ { price: price_id, quantity: 1 } ],
      customer_email: current_user_email.presence,
      success_url: "https://#{ENV.fetch("APP_HOST")}/?purchased=1",
      cancel_url: "https://#{ENV.fetch("APP_HOST")}/"
    )
    Analytics.capture(distinct_id: current_user_email || "guest", event: "checkout_started")
    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("Checkout: #{e.message}")
    redirect_to root_path, alert: "Payment is unavailable right now."
  end
end
