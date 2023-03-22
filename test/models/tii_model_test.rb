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

    task_definition.upload_requirements = [ { "key" => 'file0', "name" => 'Document 1', "type" => 'document' }, { "key" => 'file1', "name" => 'Document 2', "type" => 'document' }, { "key" => 'file2', "name" => 'Code 1', "type" => 'code' } ]

    task_definition.save!

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
      {
        id: 'file2',
        name: 'Code 1',
        type: 'code',
        filename: 'code.cs',
        "tempfile" => File.new(test_file_path('submissions/program.cs'))
      },
    ], user, nil, nil, 'ready_for_feedback', nil

    # Check that the submission is going to be progressed
    assert_equal 1, AcceptSubmissionJob.jobs.count
    refute File.exist?(task.final_pdf_path)
    assert File.directory?(FileHelper.student_work_dir(:new, task, false))

    # Check accept submission job
    AcceptSubmissionJob.clear

    response1 = TCAClient::SimpleSubmissionResponse.new id: '1222'
    response2 = TCAClient::SimpleSubmissionResponse.new id: '1223'

    submission_request = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/submissions").
    with(tii_headers).
    to_return(
      {status: 200, body: response1.to_json, headers: {}},
      {status: 200, body: response2.to_json, headers: {}},
    )

    file1_upload_req = stub_request(:put, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/original").with {|request| request.body.starts_with?('%PDF-') }.
    to_return(status: 200, body: "", headers: {})

    file2_upload_req = stub_request(:put, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1222/original").with {|request| request.body.starts_with?('%PDF-') }.
    to_return(status: 200, body: "", headers: {})

    job = AcceptSubmissionJob.new
    job.perform(task.id, user.id)

    assert_requested submission_request, times: 2

    assert File.exist?(task.final_pdf_path)

    refute File.directory?(FileHelper.student_work_dir(:new, task, false))
    assert File.exist?(task.zip_file_path_for_done_task)

    # We sent the two documents, but not the code to turn it in
    assert_requested file1_upload_req, times: 1
    assert_requested file2_upload_req, times: 1

    # We will progress the 2nd document
    subm = TiiSubmission.last
    assert_equal :uploaded, subm.status_sym

    # task destroy will trigger delete of submission
    delete_request = stub_request(:delete, /https:\/\/#{ENV['TCA_HOST']}\/api\/v1\/submissions\/\d+/).
    with(tii_headers).
    to_return(status: 200, body: "", headers: {})

    # Now trigger next step - processing to complete
    # Processing will not progress to next step
    subm_status_req = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223").
      with(tii_headers).
      to_return(
        {status: 200, body: TCAClient::Submission.new(status: 'PROCESSING').to_hash.to_json(), headers: {}},
        {status: 200, body: TCAClient::Submission.new(status: 'COMPLETE').to_hash.to_json(), headers: {}},
      )

    # Now run for "still processing"
    subm.continue_process

    assert_requested subm_status_req, times: 1
    assert_equal :uploaded, subm.reload.status_sym
    assert_equal 1, subm.retries

    # Now run for processing complete

    similarity_request = stub_request(:put, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/similarity").
    with(tii_headers).
    with(
      body: "{\"generation_settings\":{\"search_repositories\":[\"INTERNET\",\"SUBMITTED_WORK\",\"PUBLICATION\",\"CROSSREF\",\"CROSSREF_POSTED_CONTENT\"],\"auto_exclude_self_matching_scope\":\"GROUP_CONTEXT\"}}",
    ).
    to_return(status: 200, body: "", headers: {})

    subm.continue_process

    assert_requested subm_status_req, times: 2
    assert_equal :similarity_report_requested, subm.reload.status_sym
    assert_equal 0, subm.retries

    # Now check the status of the similarity report
    # response = TCAClient::SimilarityMetadata.new(
    #   status: 'PROCESSING'
    # )

    stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/similarity").
    with(tii_headers).
    to_return(
      { status: 200, body: TCAClient::SimilarityMetadata.new(status: 'PROCESSING').to_hash.to_json, headers: {}},
      { status: 200, body: TCAClient::SimilarityMetadata.new(status: 'COMPLETE').to_hash.to_json, headers: {}}
    )

    subm.continue_process
    assert_equal :similarity_report_requested, subm.reload.status_sym

    similarity_pdf_request = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/similarity/pdf").
      with(tii_headers).
      with(body: "{\"locale\":\"en-US\"}").
      to_return(status: 200, body: TCAClient::RequestPdfResponse.new(id: '9876').to_hash.to_json, headers: {})

    subm.continue_process
    assert_equal '9876', subm.reload.similarity_pdf_id
    assert_equal :similarity_pdf_requested, subm.reload.status_sym
    assert_requested similarity_pdf_request, times: 1

    # Get the PDF - after asking for status

    pdf_status_request = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/similarity/pdf/9876/status").
      with(tii_headers).
      to_return(
        {status: 200, body: TCAClient::PdfStatusResponse.new(status: 'PENDING').to_hash.to_json, headers: {}},
        {status: 200, body: TCAClient::PdfStatusResponse.new(status: 'SUCCESS').to_hash.to_json, headers: {}})

    subm.continue_process
    assert_equal :similarity_pdf_requested, subm.reload.status_sym

    download_pdf_request = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/similarity/pdf/9876").
      with(tii_headers).
      to_return(status: 200, body: File.read(test_file_path('submissions/1.2P.pdf')), headers: {})

    subm.continue_process
    assert_equal :similarity_pdf_downloaded, subm.reload.status_sym
    assert_requested download_pdf_request, times: 1
    assert File.exist?(subm.similarity_pdf_path)

    # Clean up
    task.destroy
    assert_requested delete_request, times: 2
    unit.destroy
  end
end
