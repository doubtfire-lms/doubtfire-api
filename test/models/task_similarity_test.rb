require "test_helper"

class TaskSimilarityTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TiiTestHelper

  # Test that when you create a plagiarism match link, that a moss test needs the other task
  def test_other_details
    task = FactoryBot.create(:task)

    similarity = MossTaskSimilarity.create(
      task: task,
      pct: 10
    )

    refute similarity.valid?, similarity.errors.full_messages

    similarity.other_task = task
    assert similarity.valid?, similarity.errors.full_messages

    tii_similarity = TiiTaskSimilarity.create!(
      task: task,
      pct: 10,
      tii_submission: TiiSubmission.create!(
        task: task,
        idx: 0,
        filename: 'test.doc',
        status: :created,
        submitted_by_user: task.unit.main_convenor_user
      )
    )

    assert tii_similarity.valid?, tii_similarity.errors.full_messages

  ensure
    task&.project&.unit&.destroy
  end

  # Test to ensure that pct must be between 0 and 100
  def test_similarity_pct
    task = FactoryBot.create(:task)

    similarity = MossTaskSimilarity.create(
      task: task,
      other_task: task,
      pct: 10
    )

    assert similarity.valid?, similarity.errors.full_messages

    similarity.pct = -1
    refute similarity.valid?
    similarity.pct = 101
    refute similarity.valid?

    similarity.pct = 0
    assert similarity.valid?, similarity.errors.full_messages
    similarity.pct = 100
    assert similarity.valid?, similarity.errors.full_messages
  ensure
    task&.project&.unit&.destroy
  end

  # Test ability to access similarity data from task
  def test_similarity_from_task
    task = FactoryBot.create(:task)

    MossTaskSimilarity.create(
      task: task,
      other_task: task,
      pct: 10,
      flagged: true
    )

    MossTaskSimilarity.create(
      task: task,
      other_task: task,
      pct: 5
    )

    TiiTaskSimilarity.create(
      task: task,
      pct: 10,
      flagged: true,
      tii_submission: TiiSubmission.create!(
        task: task,
        idx: 0,
        filename: 'test.doc',
        status: :created,
        submitted_by_user: task.unit.main_convenor_user
      )
    )

    TiiTaskSimilarity.create(
      task: task,
      pct: 20,
      tii_submission: TiiSubmission.create!(
        task: task,
        idx: 1,
        filename: 'test.doc',
        status: :created,
        submitted_by_user: task.unit.main_convenor_user
      )
    )

    assert_equal 4, task.task_similarities.count

    assert_equal 2, task.task_similarities.where(flagged: true).count
  ensure
    task&.project&.unit&.destroy
  end

  def test_fetch_viewer_url
    task = FactoryBot.create(:task)

    sim = TiiTaskSimilarity.create(
      task: task,
      pct: 10,
      flagged: true,
      tii_submission: TiiSubmission.create!(
        task: task,
        idx: 0,
        filename: 'test.doc',
        status: :similarity_report_complete,
        submitted_by_user: task.unit.main_convenor_user,
        submission_id: 1223
      )
    )

    add_auth_header_for(user: task.unit.main_convenor_user)

    # This will post to get the viewer url
    viewer_url_request = stub_request(:post, "https://#{ENV['TCA_HOST']}/api/v1/submissions/1223/viewer-url").
      with(tii_headers).
      to_return(status: 200, body: TCAClient::SimilarityViewerUrlResponse.new(viewer_url: 'https://viewer.url').to_hash.to_json, headers: {}
    )

    get "/api/tasks/#{task.id}/similarities/#{sim.id}/viewer_url"
    assert_equal 200, last_response.status
    assert last_response.body.include? "https://viewer.url"

    add_auth_header_for(user: task.project.student)
    get "/api/tasks/#{task.id}/similarities/#{sim.id}/viewer_url"
    assert_equal 401, last_response.status

    sim.tii_submission.update!(submission_id: nil)
    sim.destroy!
    task.destroy!
  end
end
