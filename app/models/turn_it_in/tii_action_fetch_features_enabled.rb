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

  private

  def run
    features = fetch_features_enabled
    if features.present?
      self.complete = true

      # update cache
      Rails.cache.write('tii.features_enabled', features, expires_in: 48.hours)
    else
      retry_request
    end
  end

  # Connect to tii to get the features enabled for this institution
  def fetch_features_enabled
    exec_tca_call 'fetch TII features enabled' do
      api_instance = TCAClient::FeaturesApi.new
      features = api_instance.features_enabled_get(
        TurnItIn.x_turnitin_integration_name,
        TurnItIn.x_turnitin_integration_version
      )

      # return the features
      features
    end
  end

end
