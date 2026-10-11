require "test_helper"

class AuthFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "full magic link sign-in: request, verify, welcome + admin emails" do
    assert_emails 1 do # magic link email
      post auth_path, params: { email: "new@example.com", newsletter: "1" }
      perform_enqueued_jobs
    end
    assert_redirected_to signin_path

    user = User.find_by!(email: "new@example.com")
    assert user.newsletter?
    assert user.magic_link_token.present?

    assert_emails 2 do # welcome + admin notification on first sign-in
      get verify_auth_url(token: user.magic_link_token)
      perform_enqueued_jobs
    end
    assert_redirected_to root_path
    assert cookies[:session_token].present?
    assert_equal "new@example.com", cookies[:user_email]

    admin_mail = ActionMailer::Base.deliveries.find { |m| m.to.include?(ENV["ADMIN_EMAIL"]) }
    assert admin_mail, "admin should be notified of the signup"
    assert_match(/Newsletter:\s*yes/i, admin_mail.text_part.body.to_s)
  end

  test "expired magic link is rejected" do
    post auth_path, params: { email: "late@example.com" }
    user = User.find_by!(email: "late@example.com")
    user.update!(magic_link_expires_at: 1.minute.ago)

    get verify_auth_url(token: user.magic_link_token)
    assert_redirected_to signin_path
    assert_nil cookies[:session_token].presence
  end

  test "repeat sign-in sends no welcome or admin email" do
    post auth_path, params: { email: "repeat@example.com" }
    user = User.find_by!(email: "repeat@example.com")
    get verify_auth_url(token: user.magic_link_token)
    perform_enqueued_jobs # drain first sign-in's emails

    assert_emails 1 do # only the second magic link email — no welcome/admin
      post auth_path, params: { email: "repeat@example.com" }
      user.reload
      get verify_auth_url(token: user.magic_link_token)
      perform_enqueued_jobs
    end
  end

  test "invalid email is rejected" do
    post auth_path, params: { email: "garbage" }
    assert_redirected_to signin_path
    assert_equal 0, User.count
  end

  test "sign out clears cookies" do
    post auth_path, params: { email: "out@example.com" }
    user = User.find_by!(email: "out@example.com")
    get verify_auth_url(token: user.magic_link_token)

    delete signout_path
    assert_redirected_to root_path
    assert_nil cookies[:session_token].presence
  end
end
