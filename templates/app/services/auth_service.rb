# Passwordless magic-link auth. POST /auth emails a sign-in link;
# GET /auth/verify?token=... completes it and issues an opaque session token
# stored in permanent cookies (user_email + session_token).
class AuthService
  LINK_EXPIRY = 15.minutes

  def self.start_sign_in!(email:, newsletter: false)
    user = User.find_or_initialize_by(email: email)
    is_new_user = user.new_record?
    user.newsletter ||= newsletter
    user.magic_link_token = SecureRandom.urlsafe_base64(32)
    user.magic_link_expires_at = LINK_EXPIRY.from_now
    user.save!
    AuthMailer.magic_link(user, is_new_user:).deliver_later
    Analytics.capture(distinct_id: user.email, event: "magic_link_sent")
    { user:, is_new_user: }
  end

  def self.complete_sign_in!(token:)
    user = User.find_by(magic_link_token: token)
    return nil unless user && user.magic_link_expires_at&.future?

    is_new_user = user.session_token.nil? # never completed a sign-in before
    session_token = SecureRandom.urlsafe_base64(32)
    user.update!(magic_link_token: nil, magic_link_expires_at: nil,
      session_token: session_token)

    if is_new_user
      # Only on first sign-in, so repeat sign-ins don't re-trigger these.
      UserMailer.welcome(user).deliver_later
      AdminMailer.new_signup(user).deliver_later
      SenderService.subscribe(email: user.email) if user.newsletter?
    end
    Analytics.capture(distinct_id: user.email, event: "user_authenticated")
    { user:, session_token: }
  end

  def self.verify_session(email, session_token)
    return nil if email.blank? || session_token.blank?
    user = User.find_by(email: email)
    return nil unless user&.session_token
    return nil unless ActiveSupport::SecurityUtils.secure_compare(user.session_token, session_token)
    user
  end
end
