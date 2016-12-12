# Enforce test environment
ENV["RAILS_ENV"] = "test"

namespace :test do
  desc "Setup the test database for minitest"
  task setup: [:environment, 'db:setup', 'db:migrate', 'db:populate', 'db:simulate_signoff', 'submission:update_progress'] do
  # extra things
  end
end
