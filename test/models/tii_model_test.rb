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

  def test_tii_features_enabled
    skip "TurnItIn Integration Tests Skipped" unless Doubtfire::Application.config.tii_enabled
    TiiActionFetchFeaturesEnabled.destroy_all

    body = '{
      "similarity": {
          "viewer_modes": {
              "match_overview": true,
              "all_sources": true
          },
          "generation_settings": {
              "search_repositories": [
                  "INTERNET",
                  "PUBLICATION",
                  "CROSSREF",
                  "CROSSREF_POSTED_CONTENT",
                  "SUBMITTED_WORK"
              ],
              "submission_auto_excludes": true
          },
          "view_settings": {
              "exclude_bibliography": true,
              "exclude_quotes": true,
              "exclude_abstract": true,
              "exclude_methods": true,
              "exclude_small_matches": true,
              "exclude_internet": true,
              "exclude_publications": true,
              "exclude_crossref": true,
              "exclude_crossref_posted_content": true,
              "exclude_submitted_works": true,
              "exclude_citations": true,
              "exclude_preprints": true
          }
      },
      "tenant": {
          "require_eula": true
      },
      "product_name": "Turnitin Originality",
      "access_options": [
          "NATIVE",
          "CORE_API",
          "DRAFT_COACH"
      ]
  }'

    feature_stub = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/features-enabled").
    with(tii_headers).
    to_return(
      status: 200,
      body: body,
      headers: {
        'Content-Type' => 'application/json'
      }
    )

    # Eula not required if not read
    assert TiiActionFetchFeaturesEnabled.eula_required?

    assert_equal 1, TiiActionFetchFeaturesEnabled.count
    assert_requested feature_stub, times: 1
  end

  def test_tii_process
    skip "TurnItIn Integration Tests Skipped" unless Doubtfire::Application.config.tii_enabled

    setup_tii_features_enabled

    project = FactoryBot.create(:project)
    unit = project.unit
    user = project.student
    convenor = unit.main_convenor_user
    task_definition = unit.task_definitions.first

    task_definition.upload_requirements = [
      {
        "key" => 'file0',
        "name" => 'Document 1',
        "type" => 'document',
        "tii_check" => true,
        "tii_pct" => 35
      },
      {
        "key" => 'file1',
        "name" => 'Document 2',
        "type" => 'document',
        "tii_check" => false,
        "tii_pct" => 35
      },
      {
        "key" => 'file2',
        "name" => 'Code 1',
        "type" => 'code',
        "tii_check" => true,
        "tii_pct" => 35
      },
      {
        "key" => 'file3',
        "name" => 'Document 3',
        "type" => 'document',
        "tii_check" => true,
        "tii_pct" => 35
      },
      {
        "key" => 'file4',
        "name" => 'Document 4',
        "type" => 'document'
      }
    ]

    # Stub requests to create the group
    grp_put_stub = stub_request(:put, %r[https://#{ENV['TCA_HOST']}/api/v1/groups.*]).
    with(tii_headers).
    to_return(status: 200, body: "", headers: {})

    # Saving task def will trigger TII group creation
    task_definition.save!

    # This should have put the group and created the group id
    assert_requested grp_put_stub, times: 1
    assert task_definition.reload.tii_group_id.present?
    assert TiiActionUpdateTiiGroup.last.complete
    assert TiiAction.where(entity: task_definition).exists?
    assert_equal task_definition, TiiActionUpdateTiiGroup.last.entity

    # Test that the task def is setup correctly
    assert_equal 4, task_definition.number_of_documents

    assert task_definition.use_tii?(0)
    refute task_definition.use_tii?(1)
    refute task_definition.use_tii?(2)
    assert task_definition.use_tii?(3)
    refute task_definition.use_tii?(4)

    pre_id = task_definition.tii_group_id
    # Change the due date of the task and check update
    task_definition.due_date = task_definition.due_date + 1.day
    task_definition.save

    assert TiiActionUpdateTiiGroup.last.complete
    assert_requested grp_put_stub, times: 2
    assert_equal pre_id, task_definition.reload.tii_group_id

    # Adding task resources will trigger creation and upload of the group attachments
    post_grp_attachment_stub = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/groups/#{task_definition.tii_group_id}/attachments").
      with(tii_headers).
      with(body: "{\"title\":\"TestWordDoc.docx\",\"template\":false}").
      to_return(status: 200, body: TCAClient::AddGroupAttachmentResponse.new(id: SecureRandom.uuid).to_json, headers: {})

    upload_stub = stub_request(:put, %r[https://#{ENV['TCA_HOST']}/api/v1/groups/#{task_definition.tii_group_id}/attachments/.*/original]).
      with(tii_headers).
      with(headers: {'Content-Type'=>'binary/octet-stream'}).
      to_return(status: 200, body: '{ "message": "Successfully uploaded file for attachment ..." }', headers: {})

    delete_stub = stub_request(:delete, %r[https://#{ENV['TCA_HOST']}/api/v1/groups/#{task_definition.tii_group_id}/attachments/.*]).
      with(tii_headers).
      to_return(status: 200, body: "", headers: {})

    # Lets add task resources + template
    task_definition.add_task_resources(test_file_path('TestWordDoc.docx.zip'), copy: true)

    assert task_definition.has_task_resources?
    assert_equal TiiGroupAttachment.last, TiiActionUploadTaskResources.last.entity

    assert_requested post_grp_attachment_stub, times: 1
    assert_requested upload_stub, times: 1

    # Now... lets upload a submission
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
      {
        id: 'file3',
        name: 'Document 3',
        type: 'document',
        filename: 'file3.pdf',
        "tempfile" => File.new(test_file_path('submissions/1.2P.pdf'))
      },
      {
        id: 'file4',
        name: 'Document 4',
        type: 'document',
        filename: 'file4.pdf',
        "tempfile" => File.new(test_file_path('submissions/1.2P.pdf'))
      },

    ], user, nil, nil, 'ready_for_feedback', nil, accepted_tii_eula: true

    # Check that the submission is going to be progressed
    assert_equal 1, AcceptSubmissionJob.jobs.count
    refute File.exist?(task.final_pdf_path)
    assert File.directory?(FileHelper.student_work_dir(:new, task, false))

    # Check accept submission job
    response1 = TCAClient::SimpleSubmissionResponse.new id: '1222'
    response2 = TCAClient::SimpleSubmissionResponse.new id: '1223'

    submission_request = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/submissions").
    with(tii_headers).
    to_return(
      {status: 200, body: response1.to_json, headers: {}},
      {status: 200, body: response2.to_json, headers: {}},
    )

    file1_upload_req = stub_request(:put, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/original").
      with {|request| request.body.starts_with?('%PDF-') }.
      to_return(status: 200, body: "", headers: {})

    file2_upload_req = stub_request(:put, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1222/original").
      with {|request| request.body.starts_with?('%PDF-') }.
      to_return(status: 200, body: "", headers: {})

    # Run the accept submission job - and check it all worked
    AcceptSubmissionJob.drain

    assert File.exist?(task.final_pdf_path)

    refute File.directory?(FileHelper.student_work_dir(:new, task, false))
    assert File.exist?(task.zip_file_path_for_done_task)

    assert_requested submission_request, times: 2

    # We will progress the 2 submissions...
    subm = TiiSubmission.last
    subm1 = TiiSubmission.second_to_last

    subm_act = TiiActionUploadSubmission.last
    subm1_act = TiiActionUploadSubmission.second_to_last

    assert_equal subm, subm_act.entity
    assert_equal subm1, subm1_act.entity

    # We sent the two documents, but not the code to turn it in
    assert_requested file1_upload_req, times: 1
    assert_requested file2_upload_req, times: 1

    assert_equal :uploaded, subm.status_sym

    # task destroy will trigger delete of submission
    delete_request = stub_request(:delete, /https:\/\/#{ENV['TCA_HOST']}\/api\/v1\/submissions\/\d+/).
      with(tii_headers).
      to_return(status: 200, body: "", headers: {})

    # and delete of attachments
    delete_Attachment_request = stub_request(:delete, %r[https://localhost/api/v1/groups/1/attachments/.*]).
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
    subm_act.perform

    assert_requested subm_status_req, times: 1
    assert_equal :uploaded, subm.reload.status_sym
    assert_equal 1, subm_act.reload.retries

    # Now run for processing complete
    similarity_request = stub_request(:put, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/similarity").
    with(tii_headers).
    with(
      body: "{\"generation_settings\":{\"search_repositories\":[\"INTERNET\",\"SUBMITTED_WORK\",\"PUBLICATION\",\"CROSSREF\",\"CROSSREF_POSTED_CONTENT\"],\"auto_exclude_self_matching_scope\":\"GROUP_CONTEXT\"}}",
    ).
    to_return(status: 200, body: "", headers: {})

    subm_act.perform

    assert_requested subm_status_req, times: 2
    assert_equal :similarity_report_requested, subm.reload.status_sym
    assert_equal 0, subm_act.reload.retries
    refute subm.reload.tii_task_similarity.present?

    # Now check the status of the similarity report
    # response = TCAClient::SimilarityMetadata.new(
    #   status: 'PROCESSING'
    # )

    stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/similarity").
    with(tii_headers).
    to_return(
      { status: 200, body: TCAClient::SimilarityMetadata.new(status: 'PROCESSING').to_hash.to_json, headers: {}},
      { status: 200, body: TCAClient::SimilarityMetadata.new(status: 'COMPLETE', overall_match_percentage: 50).to_hash.to_json, headers: {}}
    )

    subm_act.perform
    assert_equal :similarity_report_requested, subm.reload.status_sym

    # Next call will request to download PDF as complete...
    similarity_pdf_request = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/similarity/pdf").
      with(tii_headers).
      with(body: "{\"locale\":\"en-US\"}").
      to_return(
        {status: 500, body: 'error', headers: {}},
        {status: 200, body: TCAClient::RequestPdfResponse.new(id: '9876').to_hash.to_json, headers: {}}
      )

    # Check we got the submission details
    subm_act.perform
    assert_equal :similarity_report_complete, subm.reload.status_sym

    assert subm.reload.tii_task_similarity.present?
    assert subm.reload.tii_task_similarity.flagged
    assert_equal 50, subm.overall_match_percentage
    assert_requested similarity_pdf_request, times: 1

    subm_act.perform
    assert_equal '9876', subm.reload.similarity_pdf_id
    assert_equal :similarity_pdf_requested, subm.reload.status_sym
    assert_requested similarity_pdf_request, times: 2

    # Get the PDF - after asking for status

    pdf_status_request = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/similarity/pdf/9876/status").
      with(tii_headers).
      to_return(
        {status: 200, body: TCAClient::PdfStatusResponse.new(status: 'PENDING').to_hash.to_json, headers: {}},
        {status: 200, body: TCAClient::PdfStatusResponse.new(status: 'SUCCESS').to_hash.to_json, headers: {}})

    subm_act.perform
    assert_equal :similarity_pdf_requested, subm.reload.status_sym

    download_pdf_request = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/similarity/pdf/9876").
      with(tii_headers).
      to_return(status: 200, body: File.read(test_file_path('NotAPdf.pdf')), headers: {})

    subm_act.perform
    assert_equal :similarity_pdf_downloaded, subm.reload.status_sym
    assert_requested download_pdf_request, times: 1
    assert File.exist?(subm.similarity_pdf_path)

    # Get the viewer url
    viewer_url_request = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/viewer-url").
      with(tii_headers).
      to_return(status: 200, body: TCAClient::SimilarityViewerUrlResponse.new(viewer_url: 'https://viewer.url').to_hash.to_json, headers: {}
    )

    viewer_act = subm.create_viewer_url(subm.task.tutor)

    assert_requested viewer_url_request, times: 1
    assert_equal 'https://viewer.url', viewer_act

    # Now for submission 1
    # Stub ssubmission 1 as well
    subm_status_req = stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1222").
      with(tii_headers).
      to_return(
        {status: 200, body: TCAClient::Submission.new(status: 'COMPLETE').to_hash.to_json(), headers: {}},
      )

    similarity_request = stub_request(:put, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1222/similarity").
      with(tii_headers).
      with(
        body: "{\"generation_settings\":{\"search_repositories\":[\"INTERNET\",\"SUBMITTED_WORK\",\"PUBLICATION\",\"CROSSREF\",\"CROSSREF_POSTED_CONTENT\"],\"auto_exclude_self_matching_scope\":\"GROUP_CONTEXT\"}}",
      ).
      to_return(status: 200, body: "", headers: {})

    stub_request(:get, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1222/similarity").
      with(tii_headers).
      to_return(
        { status: 200, body: TCAClient::SimilarityMetadata.new(status: 'COMPLETE', overall_match_percentage: 5).to_hash.to_json, headers: {}}
      )

    subm1_act.perform
    assert_equal :similarity_report_requested, subm1.reload.status_sym

    subm1_act.perform
    assert_equal :complete_low_similarity, subm1.reload.status_sym

    # Clean up
    task.destroy
    assert_requested delete_request, times: 2
    unit.destroy
  end
end
