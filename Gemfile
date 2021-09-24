source 'https://rubygems.org'

# Ruby versions for various enviornments
ruby_versions = {
  development: '~>2.6.7',
  test: '~>2.6.7',
  staging: '~>2.6.7',
  production: '~>2.6.7'
}
# Get the ruby version for the current enviornment
ruby ruby_versions[(ENV['RAILS_ENV'] || 'development').to_sym]

# The venerable, almighty Rails
gem 'rails', '~>6.1.0'

group :development, :test do
  gem 'better_errors'
  gem 'byebug'
  gem 'database_cleaner'
  gem 'rails_best_practices'
  gem 'rubocop'
  gem 'rubocop-faker'
  gem 'rubocop-rails'
  gem 'simplecov', require: false
end

group :development, :test, :staging do
  # Generators for population
  gem 'factory_bot'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'minitest', '~>5.14'
  gem 'minitest-around'
  gem 'minitest-rails'
  gem 'webmock'
end

# Database
gem 'mysql2', '~>0.5.0'

# Webserver - included in development and test and optionally in production
gem 'puma', '~> 5.0'

gem 'bootsnap', '>= 1.4.4', require: false

# Extend irb for better output
gem 'hirb'

# Authentication
gem 'devise', '~> 4.7.1'
gem 'devise_ldap_authenticatable'
gem 'json-jwt', '1.7.0'
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
gem 'active_model_serializers', '~> 0.10.0'
gem 'grape'
gem 'grape-active_model_serializers', '~> 1.3.2'
gem 'grape-entity'
gem 'grape-swagger'
gem 'grape-swagger-rails'

# Miscellaneous
gem 'attr_encrypted', '~> 3.1.0'
gem 'bunny-pub-sub', '0.0.9', git: 'https://github.com/doubtfire-overseer/bunny-pub-sub'
gem 'ci_reporter'
gem 'dotenv-rails'
gem 'rack-cors', require: 'rack/cors'
gem 'require_all', '>=1.3.3'

# Excel support
gem 'roo', '~> 2.7.0'
gem 'roo-xls'

# webcal generation
gem 'icalendar', '~> 2.5', '>= 2.5.3'

gem 'rest-client', '~> 2.0'
