# Enforce test environment
ENV['RAILS_ENV'] = 'test'

namespace :test do
  desc 'Setup the test database for minitest'
  task setup: [:skip_prod, :environment, 'db:setup', 'db:migrate', 'db:populate', 'db:simulate_signoff'] do
    # extra things
  end
end
