#
# Class to interact with the Turn It In similarity api
#
class TurnItIn
  @@x_turnitin_integration_name = 'formatif-tii'
  @@x_turnitin_integration_version = '1.0'

  # Get the current eula - value is refreshed every 24 hours
  def self.eula_version
    eula = Rails.cache.fetch("tii.eula_version", expires_in: 24.hours) do
      self.fetch_eula_version
    end
    eula.version
  end

  private

  # Connect to tii to get the latest eula details.
  def self.fetch_eula_version
    api_instance = TCAClient::EULAApi.new
    api_instance.eula_version_id_get(@@x_turnitin_integration_name, @@x_turnitin_integration_version, 'latest')
  end
end
