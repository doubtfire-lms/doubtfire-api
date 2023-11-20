require 'test_helper'

module TestHelpers
  #
  # Turn It In Test Helpers
  #
  module TiiTestHelper
    module_function

    def tii_headers(base = {})
      base["headers"] = {
        'Accept'=>'application/json',
        'Authorization'=>"Bearer #{ENV['TCA_API_KEY']}",
        'Content-Type'=>'application/json',
        'X-Turnitin-Integration-Name'=>'formatif-tii',
        'X-Turnitin-Integration-Version'=>'1.0'
      }

      base
    end

    def setup_tii_features_enabled
      TiiActionFetchFeaturesEnabled.create!(
        last_run: DateTime.now,
        complete: true,
        retry: false
      )

      Rails.cache.fetch('tii.features_enabled') do
        TCAClient::FeaturesEnabled.new(
          {
            similarity: TCAClient::FeaturesSimilarity.new(
                viewer_modes: {
                    match_overview: true,
                    all_sources: true
                },
                generation_settings: TCAClient::FeaturesGenerationSettings.new(
                    search_repositories: [
                        'INTERNET',
                        'SUBMITTED_WORK',
                        'PUBLICATION',
                        'CROSSREF',
                        'CROSSREF_POSTED_CONTENT',
                    ],
                    submission_auto_excludes: true
                  ),
                view_settings: {
                    exclude_bibliography: true,
                    exclude_quotes: true,
                    exclude_abstract: true,
                    exclude_methods: true,
                    exclude_small_matches: true,
                    exclude_internet: true,
                    exclude_publications: true,
                    exclude_crossref: true,
                    exclude_crossref_posted_content: true,
                    exclude_submitted_works: true,
                    exclude_citations: true,
                    exclude_preprints: true
                }
              ),
            tenant: TCAClient::FeaturesTenant.new({
                require_eula: true
            }),
            product_name: 'Turnitin Originality',
            access_options: [
                'NATIVE',
                'CORE_API',
                'DRAFT_COACH'
            ]
        }
      )
      end
    end

    def setup_tii_eula
      TiiActionFetchEula.create!(
        last_run: DateTime.now,
        complete: true,
        retry: false
      )

      Rails.cache.fetch('tii.eula_version') do
        TCAClient::EulaVersion.new(
          version: "v1beta",
          valid_from: "2018-04-30T17:00:00Z",
          valid_until: nil,
          url: "https://static.turnitin.com/eula/v1beta/fr-fr/eula.html",
          available_languages: [
              "sv-SE",
              "zh-CN",
              "ja-JP",
              "ko-KR",
              "es-MX",
              "nl-NL",
              "ru-RU",
              "zh-TW",
              "ar-SA",
              "pt-BR",
              "de-DE",
              "el-GR",
              "nb-NO",
              "cs-CZ",
              "da-DK",
              "tr-TR",
              "pl-PL",
              "fi-FI",
              "it-IT",
              "bl-AH",
              "vi-VN",
              "fr-FR",
              "en-US",
              "ro-RO"
          ]
        )
      end
    end
  end
end
