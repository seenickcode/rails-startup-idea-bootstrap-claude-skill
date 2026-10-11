class AuthMailer < ApplicationMailer
  def magic_link(user, is_new_user: false)
    @user = user
    @url = verify_auth_url(token: user.magic_link_token)
    @is_new_user = is_new_user
    mail(to: user.email, subject: "Your sign-in link")
  end
end
