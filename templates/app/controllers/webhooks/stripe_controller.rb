module Webhooks
  class StripeController < ActionController::API
    def create
      event = Stripe::Webhook.construct_event(
        request.body.read,
        request.env["HTTP_STRIPE_SIGNATURE"],
        ENV.fetch("STRIPE_WEBHOOK_SECRET")
      )
      case event.type
      when "checkout.session.completed", "checkout.session.async_payment_succeeded"
        session = event.data.object
        email = session.customer_details&.email || session.customer_email
        if email.present? && session.payment_status == "paid"
          user = User.find_or_create_by!(email: email.downcase)
          unless user.purchased? # idempotent: completed + async_succeeded can both fire
            user.update!(purchased_at: Time.current)
            begin
              UserMailer.purchase_confirmation(user, session.amount_total).deliver_later
            rescue => e
              # purchase is still valid even if email fails
              Rails.logger.error("purchase_confirmation: #{e.message}")
            end
            Analytics.capture(distinct_id: user.email, event: "purchase_completed",
              properties: { amount_cents: session.amount_total })
          end
        end
      end
      head :ok
    rescue JSON::ParserError, Stripe::SignatureVerificationError
      head :bad_request
    end
  end
end
