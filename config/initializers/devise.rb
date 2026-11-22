Devise.setup do |config|
  config.mailer_sender = ENV.fetch("MAILER_FROM", "no-reply@example.com")
  config.parent_mailer = "ApplicationMailer"

  require "devise/orm/active_record"

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12

  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete

  # Forms are plain HTML (no Turbo), so the classic status codes are fine.
  config.responder.error_status = :unprocessable_entity if config.respond_to?(:responder)
  config.responder.redirect_status = :see_other if config.respond_to?(:responder)

  config.omniauth :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"], scope: "email,profile"
  config.omniauth :github, ENV["GITHUB_CLIENT_ID"], ENV["GITHUB_CLIENT_SECRET"], scope: "user:email"
end
