source 'https://rubygems.org'

# Ruby versions for various enviornments
ruby_versions = {
  development:  '~>3.0.2',
  test:         '~>3.0.2',
  staging:      '~>3.0.2',
  production:   '~>3.0.2'
}
# Get the ruby version for the current enviornment
ruby ruby_versions[(ENV['RAILS_ENV'] || 'development').to_sym]

# The venerable, almighty Rails
gem 'rails', '6.1.4'

group :development, :test do
  gem 'database_cleaner'
  gem 'byebug'
  gem 'simplecov', require: false
  gem 'pg'
  gem 'hirb'
  gem 'better_errors'
  gem 'rails_best_practices'
  gem 'thin'
  gem 'rubocop', '1.19.1'
  gem 'factory_bot_rails'
end

group :development, :test, :staging do
  # Generators for population
  gem 'factory_bot_rails'
  gem 'factory_bot'
  gem 'faker', '~>2.19.0'
  gem 'minitest-rails'
  gem 'minitest-around'
  gem 'webmock'
end

group :production do
  gem 'passenger', '= 6.0.10'
end

group :production, :staging do
  gem 'mysql2'
end

# Authentication
gem 'devise', '~> 4.8.0'
gem 'devise_ldap_authenticatable'
gem 'json-jwt', '1.13.0'

# Student submission
gem 'coderay'
gem 'ruby-filemagic'
gem 'rmagick', '~> 4.1' # require: false #already included in other gems - remove to avoid duplicate errors
gem 'rubyzip'

# Plagarism detection
gem 'moss_ruby', '>= 1.1.3'

# Latex
gem 'rails-latex', '=2.3.3'

# API
gem 'grape', '1.5.3'
gem 'active_model_serializers', '~> 0.10.12'
gem 'grape-active_model_serializers', '~> 1.5.2'
gem 'grape-swagger'

# Miscellaneous
gem 'attr_encrypted', '~> 3.1.0'
gem 'rack-cors', require: 'rack/cors'
gem 'ci_reporter'
gem 'require_all', '>=3.0.0'
gem 'dotenv-rails'

# Excel support
gem 'roo', '~> 2.8.3'
gem 'roo-xls'

# webcal generation
gem 'icalendar', '~> 2.7', '>= 2.5.3'

gem 'rest-client', '~> 2.1'
