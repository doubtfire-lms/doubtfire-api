source 'https://rubygems.org'

# The venerable, almighty Rails
gem 'rails', '3.2.13'

# This is how we get creative
gem 'populator'
gem 'faker'

# Auth
gem 'devise'
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

group :development do
  gem 'hirb'
  gem 'better_errors'
end

group :demo do
  gem 'pg'
end

group :development, :demo do
  gem 'thin'
end

# Use mysql2 for everything
gem 'mysql2'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'less-rails'
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'twitter-bootstrap-rails'
  gem 'd3_rails'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', platforms: :ruby

  gem 'uglifier', '>= 1.0.3'
end

gem 'whenever', require: false
