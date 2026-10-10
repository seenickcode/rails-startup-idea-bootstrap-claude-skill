require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_option("goog:loggingPrefs", { browser: "ALL" })
  end

  # Fails on JS errors, failed asset loads, CSP violations, etc.
  def assert_no_browser_errors
    errors = page.driver.browser.logs.get(:browser).select { |l| l.level == "SEVERE" }
    assert_empty errors.map(&:message), "browser console errors on #{current_url}"
  end
end
