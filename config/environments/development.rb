Doubtfire::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Sets the reference date to be used when performing date
  # comparisons. By default, the date will be Time.zone.now
  # config.reference_date = '2012-10-10 00:00:00'

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise errors if the mailer can't send
  config.action_mailer.raise_delivery_errors = true

  # Just preview emails for now
  config.action_mailer.delivery_method = :letter_opener

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Logging level (:debug, :info, :warn, :error, :fatal)
  config.log_level = :warn

  config.eager_load = false

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = true

  # Un-comment the following line as needed to print ActiveRecord queries to terminal
  # ActiveRecord::Base.logger = Logger.new(STDOUT)

  # File server location for storing student's work
  config.student_work_dir = "#{Rails.root}/student_work"
end
