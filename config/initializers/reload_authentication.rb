Rails.application.reloader.to_prepare do
  load Rails.root.join("app/helpers/authentication_helpers.rb")
  Rails.logger.info "Reloaded AuthenticationHelpers at #{Time.zone.now}"
end
