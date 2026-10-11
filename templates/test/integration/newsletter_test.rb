require "test_helper"

class NewsletterTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "subscribe sets flag, confirms to subscriber, notifies admin, creates no session" do
    assert_emails 2 do
      post newsletter_signup_path, params: { email: "sub@example.com" }
      perform_enqueued_jobs
    end
    assert_redirected_to root_path

    user = User.find_by!(email: "sub@example.com")
    assert user.newsletter?
    assert_nil user.session_token, "newsletter signup must not create a session"
    assert_nil cookies[:session_token].presence

    recipients = ActionMailer::Base.deliveries.flat_map(&:to)
    assert_includes recipients, "sub@example.com", "subscriber must get a confirmation"
    assert_includes recipients, ENV["ADMIN_EMAIL"]
    admin_mail = ActionMailer::Base.deliveries.find { |m| m.to.include?(ENV["ADMIN_EMAIL"]) }
    assert_match(/newsletter-only/i, admin_mail.text_part.body.to_s)
  end

  test "double subscribe sends emails only once" do
    post newsletter_signup_path, params: { email: "dup@example.com" }
    assert_emails 2 do
      perform_enqueued_jobs
    end
    assert_no_emails do
      post newsletter_signup_path, params: { email: "dup@example.com" }
      perform_enqueued_jobs
    end
  end

  test "invalid email is rejected" do
    post newsletter_signup_path, params: { email: "nope" }
    assert_equal 0, User.count
  end
end
