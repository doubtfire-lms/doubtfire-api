# freeze_string_literal: true

# Fetch the eula version and html from turn it in
class TiiActionFetchEula < TiiAction
  def description
    "Fetch Tii EULA"
  end

  def run
    if fetch_eula_version
      self.complete = true
    else
      retry_request
    end
  end

  # Connect to tii to get the latest eula details.
  def fetch_eula_version
    exec_tca_call 'fetch TII EULA version' do
      api_instance = TCAClient::EULAApi.new
      eula = api_instance.eula_version_id_get(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version,
        'latest'
      )

      # update cache
      Rails.cache.write('tii.eula_version', eula, expires_in: 48.hours)

      # Also check the html
      html = fetch_eula_html(eula.version)

      # return the eula
      eula.present? && html.present?
    end
  end

  # Connect to tii to get the eula html
  def fetch_eula_html(eula_version)
    # Only update if we do not have the html for this version...
    Rails.cache.fetch("tii.eula_html.#{eula_version}", expires_in: 365.days) do
      exec_tca_call "fetch TII EULA html for #{eula_version}" do
        # Get the eula html - and return it to store in cache
        TCAClient::EULAApi.new.eula_version_id_view_get(
          TurnItIn.x_turnitin_integration_name,
          TurnItIn.x_turnitin_integration_version,
          eula_version
        )
      end
    end
  end
end
