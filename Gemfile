source 'https://rubygems.org'

# Ruby versions for various enviornments
ruby_versions = {
  development:  '~>2.6.7',
  test:         '~>2.6.7',
  staging:      '~>2.6.7',
  production:   '~>2.6.7'
}
# Get the ruby version for the current enviornment
ruby ruby_versions[(ENV['RAILS_ENV'] || 'development').to_sym]

# The venerable, almighty Rails
gem 'rails', '4.2.8'

group :development, :test do
  gem 'database_cleaner'
  gem 'byebug'
  gem 'simplecov', require: false
  gem 'better_errors'
  gem 'rails_best_practices'
  gem 'rubocop', '0.46.0'
end

group :development, :test, :staging do
  # Generators for population
  gem 'factory_bot_rails'
  gem 'factory_bot'
  gem 'faker', '~>1.9.1'
  gem 'minitest', '~>5.14'
  gem 'minitest-rails'
  gem 'minitest-around'
  gem 'webmock'
end

# Optional passenger gem
# usage: bundle --with-env=passenger
group :passenger do
  gem 'passenger', '= 4.0.42'
end

# Database
gem 'mysql2', '0.4.10'

# Webserver - included in development and test and optionally in production
# usage: bundle --with-env=webserver
group :development, :test, :webserver do
  gem 'thin'
end

# Extend irb for better output
gem 'hirb'

# Authentication
gem 'devise', '~> 4.4.0'
gem 'devise_ldap_authenticatable'
gem 'json-jwt', '1.7.0'

# Student submission
gem 'coderay'
gem 'ruby-filemagic'
gem 'rmagick', '~> 4.1' # require: false #already included in other gems - remove to avoid duplicate errors
gem 'rubyzip'

# Plagarism detection
gem 'moss_ruby', '>= 1.1.2'

# Latex
gem 'rails-latex', '=2.0.1'

# API
gem 'grape', '~> 0.16.2'
gem 'active_model_serializers', '~> 0.9.0'
gem 'grape-active_model_serializers', '~> 1.3.2'
gem 'grape-swagger'

# Miscellaneous
gem 'attr_encrypted', '~> 1.4.0'
gem 'rack-cors', require: 'rack/cors'
gem 'ci_reporter'
gem 'require_all', '>=1.3.3'
gem 'dotenv-rails'
gem 'bunny-pub-sub', '0.5.2'

# Excel support
gem 'roo', '~> 2.7.0'
gem 'roo-xls'

# webcal generation
gem 'icalendar', '~> 2.5', '>= 2.5.3'

gem 'rest-client', '~> 2.0'
