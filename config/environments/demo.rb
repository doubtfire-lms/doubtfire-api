Doubtfire::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable Rails's static asset server (Apache or nginx will already do this)
  config.serve_static_assets = false

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = false

  # Pre-compiled CSS
  config.assets.precompile += %w[
    burndown.css
    convenor.css
    convenor_project.css
    convenor_contact_form.css
    dashboard.css
    home.css
    tasks.css
    tutor_projects.css
    users.css
  ]

  # Pre-compiled JS
  config.assets.precompile += %w[
    administration.js
    bootstrap.js
    burndown.js
    convenor.js
    convenor_projects.js
    home.js
    projects.js
    status_distribution.js
    task_popover.js
    tasks.js
    tutor_projects.js
    users.js
  ]

  # Generate digests for assets URLs
  config.assets.digest = true

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify
end
