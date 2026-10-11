class UserMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail(to: user.email, subject: "Welcome!")
  end

  def newsletter_confirmation(user)
    @user = user
    mail(to: user.email, subject: "You're subscribed")
  end

  def purchase_confirmation(user, amount_cents)
    @user = user
    @amount = ActiveSupport::NumberHelper.number_to_currency(amount_cents / 100.0)
    mail(to: user.email, subject: "Thanks for your purchase")
  end
end
