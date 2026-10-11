ENV["RAILS_ENV"] ||= "test"
ENV["ADMIN_EMAIL"] ||= "admin@example.com"
ENV["APP_HOST"] ||= "example.com"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Add more helper methods to be used by all tests here...
  end
end
