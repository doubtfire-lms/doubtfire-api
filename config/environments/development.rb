Doubtfire::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # File server location for storing student's work
  config.student_work_dir = "#{Rails.root}/student_work"

  config.secret_attr_key = '536d7e62379a0871ec67434ed38682662c5b8d0f0da801c654a9b3ca0585e615a3447a89f8e4e8a6c576fcdc8ef91b0beb3ba76d3b60f88d4c7f540f03996bc7'
  config.secret_key_base = '3c5a1b90b831b6d9e23a19b22ce7c1ea2bce07fc4b32a664daa0eac211b8069decdf82a20779eeb6ae57e08347a848c89a58c78971abc2e5137a419e5bfbac0c'

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
  config.action_mailer.delivery_method = :file
  config.mail_base_url = "http://localhost:8000/\#/"

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

  config.moss_key = "924185900"
end
