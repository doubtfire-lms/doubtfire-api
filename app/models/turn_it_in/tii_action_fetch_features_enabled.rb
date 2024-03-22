# freeze_string_literal: true

# Fetch the eula version and html from turn it in
class TiiActionFetchFeaturesEnabled < TiiAction
  def description
    "Fetch Tii Features Enabled"
  end

  def self.eula_required?
    features = Rails.cache.read('tii.features_enabled')

    unless features.present? && features.tenant.present?
      (TiiActionFetchFeaturesEnabled.last || TiiActionFetchFeaturesEnabled.create).perform

      features = Rails.cache.read('tii.features_enabled')
    end

    return false if features.nil? || features.tenant.nil?
    features.tenant.require_eula
  end

  def self.search_repositories
    features = Rails.cache.read('tii.features_enabled')

    unless features.present? && features.similarity.present? && features.similarity.generation_settings.present?
      (TiiActionFetchFeaturesEnabled.last || TiiActionFetchFeaturesEnabled.create).perform

      features = Rails.cache.read('tii.features_enabled')
    end

    if features.nil? || features.similarity.nil? || features.similarity.generation_settings.nil?
      return %w[
        INTERNET
        SUBMITTED_WORK
        PUBLICATION
        CROSSREF
        CROSSREF_POSTED_CONTENT
      ]
    end

    features.similarity.generation_settings.search_repositories
  end

  # Check if an update of the features is required
  def update_required?
    last_feature_check = last_run

    !Rails.cache.exist?('tii.features_enabled') ||
      last_feature_check.nil? ||
      last_feature_check < DateTime.now - 1.day
  end

  def fetch_features_enabled
    # Attempt to load the feature from file
    data = load_feature_yaml
    features = if data && data['features'] && data['expire'] && data['expire'] > DateTime.now
                 data['features']
               else
                 fetch_features_enabled_from_tii
               end
    # update cache
    Rails.cache.write('tii.features_enabled', features, expires_in: 48.hours)
    features
  end

  def self.feature_yaml_path
    "#{FileHelper.student_work_root}/tii_feature.yml"
  end

  private

  def run
    features = fetch_features_enabled
    if features.present?
      self.complete = true
    else
      retry_request
    end
  end

  def feature_yaml_path
    self.class.feature_yaml_path
  end

  def load_feature_yaml
    require 'yaml' # Built in, no gem required
    YAML.load_file(feature_yaml_path, permitted_classes: [DateTime, Time, TCAClient::FeaturesEnabled, TCAClient::FeaturesSimilarity, TCAClient::FeaturesViewerModes, TCAClient::FeaturesGenerationSettings, TCAClient::FeaturesSimilarityViewSettings, TCAClient::FeaturesTenant]) if File.exist?(feature_yaml_path) # Load
  rescue StandardError
    nil
  end

  def save_feature_yaml(data)
    require 'yaml' # Built in, no gem required
    File.write feature_yaml_path, data.to_yaml
  end

  # Connect to tii to get the features enabled for this institution
  def fetch_features_enabled_from_tii
    exec_tca_call 'fetch TII features enabled' do
      api_instance = TCAClient::FeaturesApi.new
      features = api_instance.features_enabled_get(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version
      )

      # Update the feature yaml
      if features.present?
        data = {}
        data['expire'] = DateTime.now + 2.days
        data['features'] = features

        # Save the eula to a cache file
        save_feature_yaml(data)
      end

      # return the features
      features
    end
  end

end
