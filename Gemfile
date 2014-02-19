source 'https://rubygems.org'

# The venerable, almighty Rails
gem 'rails', '3.2.13'

# This is how we get creative
gem 'populator'
gem 'faker'

# Auth
gem 'devise', '~> 3.1.2'
gem 'devise_ldap_authenticatable'
gem 'cancan'

# Show off our Gucci emails before they get sent off
gem 'letter_opener'

# Paging and JS
gem 'kaminari'
gem 'jquery-rails'

# Hey girl, I like your form. Why don't you come over here
# and validate me.
gem 'simple_form'
gem 'bootstrap-datepicker-rails'

gem 'pg'

group :development do
  gem 'hirb'
  gem 'better_errors'
  gem 'rails_best_practices'
  gem 'thin'
end

group :test do
  gem 'faker'
  gem 'simplecov'
  gem 'capybara'
  gem 'launchy'
  gem 'ci_reporter'
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'less-rails'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'twitter-bootstrap-rails'
  gem 'd3_rails'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', platforms: :ruby
  gem 'uglifier', '>= 1.0.3'
end

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
end
