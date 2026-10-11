require "test_helper"

class StripeWebhookTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  SECRET = "whsec_test_secret"

  setup do
    ENV["STRIPE_WEBHOOK_SECRET"] = SECRET
  end

  def signed_headers(payload)
    timestamp = Time.now.to_i
    signature = Stripe::Webhook::Signature.compute_signature(
      Time.at(timestamp), payload, SECRET
    )
    { "Stripe-Signature" => "t=#{timestamp},v1=#{signature}", "Content-Type" => "application/json" }
  end

  def checkout_completed_payload(email:)
    {
      id: "evt_test_1", object: "event", type: "checkout.session.completed",
      data: { object: {
        id: "cs_test_1", object: "checkout.session",
        payment_status: "paid", amount_total: 500,
        customer_details: { email: email }, customer_email: email
      } }
    }.to_json
  end

  test "signed checkout.session.completed marks user purchased and emails confirmation" do
    payload = checkout_completed_payload(email: "buyer@example.com")
    assert_emails 1 do
      post "/webhooks/stripe", params: payload, headers: signed_headers(payload)
      perform_enqueued_jobs
    end
    assert_response :ok

    user = User.find_by!(email: "buyer@example.com")
    assert user.purchased?
  end

  test "replayed event is idempotent" do
    payload = checkout_completed_payload(email: "again@example.com")
    post "/webhooks/stripe", params: payload, headers: signed_headers(payload)
    first_purchased_at = User.find_by!(email: "again@example.com").purchased_at
    perform_enqueued_jobs # drain the first event's confirmation email

    assert_no_emails do
      post "/webhooks/stripe", params: payload, headers: signed_headers(payload)
      perform_enqueued_jobs
    end
    assert_equal first_purchased_at, User.find_by!(email: "again@example.com").purchased_at
  end

  test "bad signature is rejected" do
    payload = checkout_completed_payload(email: "evil@example.com")
    post "/webhooks/stripe", params: payload,
      headers: { "Stripe-Signature" => "t=1,v1=bad", "Content-Type" => "application/json" }
    assert_response :bad_request
    assert_nil User.find_by(email: "evil@example.com")
  end
end
