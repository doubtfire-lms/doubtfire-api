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

    def setup_tii_eula
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
