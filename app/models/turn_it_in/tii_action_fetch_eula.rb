# freeze_string_literal: true

# Fetch the eula version and html from turn it in
class TiiActionFetchEula < TiiAction
  def description
    "Fetch Tii EULA"
  end

  def run
    if fetch_eula_from_tii
      self.complete = true
    else
      retry_request
    end
  end

  # Check if an update of the eula is required
  def update_required?
    last_eula_check = last_run

    !Rails.cache.exist?('tii.eula_version') ||
      last_eula_check.nil? ||
      last_eula_check < DateTime.now - 1.day
  end

  def eula?
    Rails.cache.exist?('tii.eula_version')
  end

  def self.eula_yaml_path
    "#{FileHelper.student_work_root}/tii_eula.yml"
  end

  def eula_yaml_path
    self.class.eula_yaml_path
  end

  def load_eula_yaml
    require 'yaml' # Built in, no gem required
    YAML.load_file(eula_yaml_path, permitted_classes: [Time, DateTime, TCAClient::EulaVersion]) if File.exist?(eula_yaml_path) # Load
  rescue StandardError
    nil
  end

  def save_eula_yaml(data)
    require 'yaml' # Built in, no gem required
    File.write eula_yaml_path, data.to_yaml
  end

  def fetch_eula_from_tii
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

      # Update the eula yaml
      if eula.present? && html.present?
        data = {}
        data['expire'] = DateTime.now + 2.days
        data['eula'] = eula
        data["html-#{eula.version}"] = html

        # Save the eula to a cache file
        save_eula_yaml(data)
      end

      # return the eula
      eula.present? && html.present?
    end
  end

  # Connect to tii to get the latest eula details.
  def fetch_eula_version
    # Attempt to load the eula from file
    data = load_eula_yaml
    if data && data['eula'] && data['expire'] && data['expire'] > DateTime.now
      # update cache
      Rails.cache.write('tii.eula_version', data['eula'], expires_in: 48.hours)
      fetch_eula_html(data['eula'].version)
      true
    else
      fetch_eula_from_tii
    end
  end

  # Connect to tii to get the eula html
  def fetch_eula_html(eula_version)
    # Only update if we do not have the html for this version...
    Rails.cache.fetch("tii.eula_html.#{eula_version}", expires_in: 365.days) do
      require 'yaml' # Built in, no gem required
      data = load_eula_yaml # Load

      html =  (data && data["html-#{eula_version}"]) ||
              exec_tca_call("fetch TII EULA html for #{eula_version}") do
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
