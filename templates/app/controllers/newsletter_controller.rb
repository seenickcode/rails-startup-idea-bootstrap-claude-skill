# Subscribe-only path: sets the flag, syncs to Sender, notifies the admin,
# but deliberately creates NO session — sessions require the magic link
# (anyone could type someone else's address).
class NewsletterController < ApplicationController
  def create
    email = params[:email].to_s.strip.downcase
    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      return redirect_to root_path, alert: "That email doesn't look right."
    end
    user = User.find_or_initialize_by(email:)
    was_subscribed = user.persisted? && user.newsletter?
    user.newsletter = true
    user.save!
    unless was_subscribed
      SenderService.subscribe(email:)
      UserMailer.newsletter_confirmation(user).deliver_later
      AdminMailer.new_signup(user, newsletter_only: true).deliver_later
      Analytics.capture(distinct_id: email, event: "newsletter_subscribed")
    end
    redirect_to root_path, notice: "You're subscribed — thanks!"
  end
end
