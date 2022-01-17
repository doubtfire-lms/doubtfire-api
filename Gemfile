source 'https://rubygems.org'

# Ruby versions for various enviornments
ruby_versions = {
  development: '~>3.1.0',
  test: '~>3.1.0',
  staging: '~>3.1.0',
  production: '~>3.1.0'
}
# Get the ruby version for the current enviornment
ruby ruby_versions[(ENV['RAILS_ENV'] || 'development').to_sym]

# The venerable, almighty Rails
gem 'rails', '~>7.0.0'

group :development, :test do
  gem "sprockets-rails"
  gem 'better_errors'
  gem 'byebug'
  gem 'database_cleaner'
  gem 'rails_best_practices'
  gem 'rubocop'
  gem 'rubocop-faker'
  gem 'rubocop-rails'
  gem 'simplecov', require: false
  gem 'listen'
end

group :development, :test, :staging do
  # Generators for population
  gem 'factory_bot'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'minitest'
  gem 'minitest-around'
  gem 'webmock'
end

# Database
gem 'mysql2'

# Webserver - included in development and test and optionally in production
gem 'puma', '~> 5.5'

gem 'bootsnap', '>= 1.4.4', require: false

# Extend irb for better output
gem 'hirb'

# Authentication
gem 'devise'
gem 'devise_ldap_authenticatable'
gem 'json-jwt'
gem 'ruby-saml', '~> 1.13.0'

# Student submission
gem 'coderay'
gem 'rmagick', '~> 4.1' # require: false #already included in other gems - remove to avoid duplicate errors
gem 'ruby-filemagic'
gem 'rubyzip'

# Plagarism detection
gem 'moss_ruby', '>= 1.1.2'

# Latex
gem 'rails-latex', '>2.3'

# API
gem 'grape'
gem 'grape-entity'
gem 'grape-swagger'
gem 'grape-swagger-rails'

# Miscellaneous
gem 'ci_reporter'
gem 'dotenv-rails'
gem 'rack-cors', require: 'rack/cors'
gem 'require_all', '>=1.3.3'
gem 'bunny-pub-sub', '0.5.2'

# Excel support
gem 'roo', '~> 2.7.0'
gem 'roo-xls'

# webcal generation
gem 'icalendar', '~> 2.5', '>= 2.5.3'

gem 'rest-client', '~> 2.0'

gem 'net-smtp', require: false
