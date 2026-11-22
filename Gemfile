source "https://rubygems.org"

gem "rails", "~> 8.0.0"
gem "propshaft"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"

# Authentication: e-mail + password with confirmation, Google and GitHub sign-in
gem "devise", ">= 4.9.4"
gem "omniauth-google-oauth2"
gem "omniauth-github"
gem "omniauth-rails_csrf_protection"

gem "kaminari"      # pagination
gem "ransack"       # sorting and filtering of tables
gem "redcarpet"     # Markdown rendering
gem "caxlsx"        # Excel export
gem "csv"           # CSV export
gem "json", "< 3"   # Rails 8.0 passes an option that json 3 no longer accepts

gem "tzinfo-data", platforms: %i[windows jruby]
gem "resend"

group :development, :test do
  gem "dotenv-rails"
  gem "debug", platforms: %i[mri windows]
end
