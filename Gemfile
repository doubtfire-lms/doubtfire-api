source 'https://rubygems.org'
ruby '2.1.2'

# The venerable, almighty Rails
gem 'rails', '4.0.3'

# This is how we get creative
gem 'populator'
gem 'faker'

# Auth
gem 'devise', '~> 3.1.2'
gem 'devise_ldap_authenticatable'
# gem 'cancan'
gem 'attr_encrypted', '~> 1.3.2'

gem 'pg'

gem 'grape', '0.6.1'
gem 'grape-active_model_serializers', '~> 1.0.0'
gem 'grape-swagger'

gem 'rack-cors', require: 'rack/cors'

group :development do
  gem 'hirb'
  gem 'better_errors'
  gem 'rails_best_practices'
  gem 'thin'
end

group :test do
  gem 'simplecov'
  gem 'capybara'
  gem 'launchy'
  gem 'ci_reporter'
end

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
end

# Student submission
gem 'coderay'
gem 'ruby-filemagic'
gem 'rmagick', require: false #already included in other gems - remove to avoid duplicate errors
gem 'pdfkit'
gem 'wkhtmltopdf-binary-11'
gem 'pdftk'
