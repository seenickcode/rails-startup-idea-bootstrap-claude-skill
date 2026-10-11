require "test_helper"

class HomeTest < ActionDispatch::IntegrationTest
  test "homepage renders hello with newsletter form" do
    get root_path
    assert_response :success
    assert_select "h1", "hello"
    assert_select "form[action=?]", newsletter_signup_path
  end

  test "health check responds ok" do
    get "/up"
    assert_response :success
  end
end
