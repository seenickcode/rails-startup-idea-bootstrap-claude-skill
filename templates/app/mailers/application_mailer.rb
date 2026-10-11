class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("POSTMARK_FROM_EMAIL", "hello@#{ENV.fetch("APP_HOST", "localhost")}") }
  layout "mailer"
end
