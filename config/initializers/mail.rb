Rails.application.configure do
  host = ENV.fetch("APP_HOST", "localhost:3000")
  config.action_mailer.default_url_options = { host: host, protocol: ENV.fetch("APP_PROTOCOL", Rails.env.production? ? "https" : "http") }

  if Rails.env.test?
    # tests never send real mail; config/environments/test.rb sets the :test delivery method
  elsif ENV["RESEND_API_KEY"].present?
    Resend.api_key = ENV["RESEND_API_KEY"]
    config.action_mailer.delivery_method = :resend
  elsif ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV["SMTP_ADDRESS"],
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: :plain,
      enable_starttls_auto: true
    }
  else
    config.action_mailer.delivery_method = :test
  end
end
