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
gem 'cancan'

gem 'pg'

gem 'grape'
gem 'grape-active_model_serializers'
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
