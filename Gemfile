source 'https://rubygems.org'

# Ruby versions for various enviornments
ruby_versions = {
  development:  '2.3.1',
  test:         '2.3.1',
  staging:      '2.3.1',
  production:   '2.3.1'
}
# Get the ruby version for the current enviornment
ruby ruby_versions[(ENV['RAILS_ENV'] || 'development').to_sym]

# The venerable, almighty Rails
gem 'rails', '4.2.6'

group :development do
  gem 'pg'
  gem 'hirb'
  gem 'better_errors'
  gem 'rails_best_practices'
  gem 'thin'
  gem 'rubocop', '0.46.0'
end

group :development, :test do
  gem 'database_cleaner'
  gem 'factory_girl_rails'
  gem 'minitest-around'
  gem 'minitest-hyper'
  gem 'minitest-osx'
  gem 'minitest-rails'
end

group :production do
  gem 'passenger', '= 4.0.42'
end

group :production, :staging do
  gem 'mysql2'
end

# Authentication
gem 'devise', '~> 4.1.1'
gem 'devise_ldap_authenticatable'
gem 'json-jwt', '1.7.0'

# Generators for population
gem 'populator'
gem 'faker'

# Student submission
gem 'coderay'
gem 'ruby-filemagic'
gem 'rmagick', '~> 2.15' # require: false #already included in other gems - remove to avoid duplicate errors
gem 'rubyzip'

# Plagarism detection
gem 'moss_ruby', '= 1.1.2'

# Latex
gem 'rails-latex', '=2.0.1'

# API
gem 'grape', '0.16.2'
gem 'active_model_serializers', '~> 0.9.0'
gem 'grape-active_model_serializers', '~> 1.3.2'
gem 'grape-swagger'

# Miscellaneous
gem 'attr_encrypted', '~> 1.3.2'
gem 'rack-cors', require: 'rack/cors'
gem 'ci_reporter'
gem 'require_all', '1.3.3'
gem 'dotenv-rails'

# Excel support
gem "roo", "~> 2.7.0"
gem 'roo-xls'
