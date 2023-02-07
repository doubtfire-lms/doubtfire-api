require 'test_helper'
require 'tca_client'
require 'json'

class TiiModelTest < ActiveSupport::TestCase
  include TestHelpers::TiiTestHelper
  include TestHelpers::TestFileHelper

  def test_fetch_eula
    skip "TurnItIn Integration Tests Skipped" unless Doubtfire::Application.config.tii_enabled

    Rails.cache.delete('tii.eula_version')

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
    with(tii_headers).
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
    skip "TurnItIn Integration Tests Skipped" unless Doubtfire::Application.config.tii_enabled

    Rails.cache.delete('tii.eula_version')

    eula_version_stub = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/eula/latest").
    with(tii_headers).
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

  def test_tii_process
    skip "TurnItIn Integration Tests Skipped" unless Doubtfire::Application.config.tii_enabled

    project = FactoryBot.create(:project)
    unit = project.unit
    user = project.student
    convenor = unit.main_convenor_user
    task_definition = unit.task_definitions.first

    task_definition.upload_requirements = [ { "key" => 'file0', "name" => 'Document 1', "type" => 'document' }, { "key" => 'file1', "name" => 'Document 2', "type" => 'document' } ]

    assert_equal 2, task_definition.number_of_documents

    task = project.task_for_task_definition(task_definition)

    # Create a submission
    task.accept_submission user, [
      {
        id: 'file0',
        name: 'Document 1',
        type: 'document',
        filename: 'file0.pdf',
        "tempfile" => File.new(test_file_path('submissions/1.2P.pdf'))
      },
      {
        id: 'file1',
        name: 'Document 2',
        type: 'document',
        filename: 'file1.pdf',
        "tempfile" => File.new(test_file_path('submissions/1.2P.pdf'))
      },
    ], user, nil, nil, 'ready_for_feedback', nil

    assert File.directory?(FileHelper.student_work_dir(:new, task, false))
    assert task.compress_new_to_done
    assert File.exist?(task.zip_file_path_for_done_task)

    task.destroy
    unit.destroy
  end
end
