# Notifies the site admin on every new signup, indicating whether the person
# opted into the newsletter (or came through the newsletter-only form).
class AdminMailer < ApplicationMailer
  def new_signup(user, newsletter_only: false)
    @user = user
    @newsletter_only = newsletter_only
    mail(to: ENV.fetch("ADMIN_EMAIL"),
      subject: "[#{ENV.fetch("APP_HOST", "site")}] New signup: #{user.email}")
  end
end
