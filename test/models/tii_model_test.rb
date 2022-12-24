require 'test_helper'
require 'tca_client'
require 'json'

class TiiModelTest < ActiveSupport::TestCase
  def setup
    WebMock.reset_executed_requests!
  end

  def test_fetch_eula
    refute Rails.cache.fetch('tii.eula_version').present?

    eula_response = TCAClient::EulaVersion.new(
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
    ).to_hash.to_json

    eula_page = '''
<!DOCTYPE html>
<html>
    <head>
        <title>English EULA</title>
    </head>
    <body>
        <div>
            <p>This is an end-user license agreement.</p>
        </div>
    </body>
</html>'''

    eula_version_stub = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/eula/latest").
    with(
      headers: {
            'Accept'=>'application/json',
            'Authorization'=>'Bearer ea06e5dcfe8c4c6fbbb561ef68af71e0',
            'Content-Type'=>'application/json',
            'Expect'=>'',
            'User-Agent'=>'OpenAPI-Generator/1.0.1/ruby',
            'X-Turnitin-Integration-Name'=>'formatif-tii',
            'X-Turnitin-Integration-Version'=>'1.0'
      }).
    to_return(
      body: eula_response,
      status: 200,
      headers: {
        'Content-Type' => 'application/json'
      }
    )

    eula_page_stub = stub_request(:get, /https:\/\/#{ENV['TCA_HOST']}\/api\/v1\/eula\/v1beta\/view/).to_return(body: eula_page, status: 200)

    assert_equal 'v1beta', TurnItIn.eula_version
    assert_equal eula_page, TurnItIn.eula_html

    assert_requested eula_version_stub, times: 1
    assert_requested eula_page_stub, times: 1

    # Read it again... from cache
    assert_equal 'v1beta', TurnItIn.eula_version
    assert_equal eula_page, TurnItIn.eula_html

    assert_requested eula_version_stub, times: 1
    assert_requested eula_page_stub, times: 1
  end

  def test_fetch_eula_error_handling
    eula_version_stub = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/eula/latest").
    with(
      headers: {
            'Accept'=>'application/json',
            'Authorization'=>'Bearer ea06e5dcfe8c4c6fbbb561ef68af71e0',
            'Content-Type'=>'application/json',
            'Expect'=>'',
            'User-Agent'=>'OpenAPI-Generator/1.0.1/ruby',
            'X-Turnitin-Integration-Name'=>'formatif-tii',
            'X-Turnitin-Integration-Version'=>'1.0'
      }).
    to_return(
      body: 'An unexpected error was encountered',
      status: 500,
      headers: {
        'Content-Type' => 'application/json'
      }
    )

    assert_nil TurnItIn.eula_version

    assert_requested eula_version_stub, times: 1
  end
end
