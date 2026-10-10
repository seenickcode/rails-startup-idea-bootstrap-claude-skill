require "application_system_test_case"

# Real-browser smoke test: public pages load with CSS/JS and no console
# errors, and magic-link sign-in works end to end. Runs in CI's system-test job.
class SmokeTest < ApplicationSystemTestCase
  test "public pages load without browser errors" do
    visit "/"
    assert_selector "h1", text: "hello"
    assert_no_browser_errors

    visit "/signin"
    assert_selector "form input[type=email]"
    assert_no_browser_errors
  end

  test "magic-link sign in and sign out" do
    visit "/signin"
    fill_in "email", with: "browser@example.com"
    click_button "Email me a sign-in link"
    assert_text "Check your email"

    token = User.find_by!(email: "browser@example.com").magic_link_token
    visit "/auth/verify?token=#{token}"
    assert_text "Signed in as browser@example.com"

    click_button "Sign out"
    assert_text "Signed out."
    assert_no_browser_errors
  end
end
