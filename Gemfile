# frozen_string_literal: true

source 'https://rubygems.org'

# Ruby versions for various enviornments
ruby_versions = {
  development: '~>3.4.0',
  test: '~>3.4.0',
  staging: '~>3.4.0',
  production: '~>3.4.0'
}
# Get the ruby version for the current enviornment
ruby ruby_versions[(ENV['RAILS_ENV'] || 'development').to_sym]

# The venerable, almighty Rails
gem 'rails', '~>8.0'

group :development, :test do
  gem 'better_errors'
  gem 'byebug'
  gem 'database_cleaner-active_record'
  gem 'listen'
  gem 'rails_best_practices'
  gem 'rubocop'
  gem 'rubocop-factory_bot'
  gem 'rubocop-faker'
  gem 'rubocop-minitest'
  gem 'rubocop-performance'
  gem 'rubocop-rails'
  gem 'ruby-lsp'
  gem 'simplecov', require: false
  gem 'solargraph'
  gem 'sprockets-rails'
end

group :development, :test, :staging do
  # Generators for population
  gem 'factory_bot'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'minitest'
  gem 'minitest-around'
  gem 'minitest-rails'
  gem 'webmock'
end

# Database
gem 'mysql2'

# Webserver - included in development and test and optionally in production
gem 'puma', '>= 6.4.3'

gem 'bootsnap', require: false
gem 'csv'

# Extend irb for better output
gem 'hirb'

# Authentication
gem 'devise'
gem 'devise_ldap_authenticatable'
gem 'json-jwt'
gem 'ruby-saml'

# Student submission
gem 'coderay'
gem 'rmagick'
gem 'ruby-filemagic'
gem 'rubyzip'

# Plagarism detection
gem 'moss_ruby'

# Latex
gem 'rails-latex'

# API
gem 'grape'
gem 'grape-entity'
gem 'grape-swagger'
gem 'grape-swagger-rails'

# Miscellaneous
gem 'bunny-pub-sub', '0.5.2'
gem 'ci_reporter'
gem 'dotenv'
gem 'rack-cors', require: 'rack/cors'
gem 'require_all', '>=1.3.3'

# Excel support
gem 'roo'
gem 'roo-xls'

# webcal generation
gem 'icalendar'

gem 'rest-client'

gem 'net-smtp', require: false

# Turn it in
gem 'tca_client'

# Async jobs
gem 'sidekiq'
gem 'sidekiq-cron'
gem 'sidekiq-status'
gem 'sidekiq-unique-jobs'

# Redis for sidekiq, caching, and action cable (eventually)
gem 'redis'

# shellwords for safely escaping strings
gem 'shellwords'

# PDF reader for validating PDF file submissions
gem 'pdf-reader'

# oauth gem for OAuth2 authentication - D2L
gem 'oauth2'

gem "sys-filesystem"
