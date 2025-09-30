require "test_helper"

class TaskSimilarityTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TiiTestHelper
  include TestHelpers::TestFileHelper

  def test_jplag_similarity_pct
    unit = FactoryBot.create(:unit, code: 'COS10001', with_students: false, stream_count: 0)
    td = FactoryBot.create(:task_definition, unit: unit, abbreviation: 'java-1', outcome_count: 0, similarity_language: "java", plagiarism_warn_pct: 10)

    td.upload_requirements = [
      {
        "key" => 'file0',
        "name" => 'java',
        "type" => 'code',
        "tii_check" => true
      }
    ]

    td.similarity_language = "java"
    td.plagiarism_warn_pct = 25
    td.save!

    # Initialise students
    student1 = FactoryBot.create(:user, :student)
    student1_project = FactoryBot.create(:project, user_id: student1.id, unit: unit)

    student2 = FactoryBot.create(:user, :student)
    student2_project = FactoryBot.create(:project, user_id: student2.id, unit: unit)

    # Submit java file student1
    add_auth_header_for(user: student1)

    data_to_post = {
      trigger: 'ready_for_feedback'
    }
    data_to_post = with_file('test_files/submissions/jplag/Angry Coyote/sociologia.java', 'text/x-java-source', data_to_post)

    post "/api/projects/#{student1_project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status

    student1_task = student1_project.task_for_task_definition(td)
    student1_task.convert_submission_to_pdf(log_to_stdout: false)
    assert File.exist? student1_task.final_pdf_path
    assert student1_task.has_pdf

    # Submit duplicate file for student_2
    add_auth_header_for(user: student2)

    post "/api/projects/#{student2_project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status

    student2_task = student2_project.task_for_task_definition(td)
    student2_task.convert_submission_to_pdf(log_to_stdout: false)
    assert File.exist? student2_task.final_pdf_path
    assert student2_task.has_pdf

    # Run jplag
    unit.check_jplag_similarity(force: true)

    # Validate similarities
    similarity1 = JplagTaskSimilarity.find_by(task_id: student1_task.id)
    similarity2 = JplagTaskSimilarity.find_by(task_id: student2_task.id)

    assert_not_nil similarity1, "Similarity1 does not exist"
    assert_not_nil similarity2, "Similarity2 does not exist"

    assert similarity1.valid?, similarity1.errors.full_messages
    assert similarity2.valid?, similarity2.errors.full_messages

    assert_not_nil similarity1.other_task, "Similarity1 'other_task' is nil"
    assert_not_nil similarity2.other_task, "Similarity2 'other_task' is nil"

    assert similarity1.other_task.valid?, similarity1.errors.full_messages
    assert similarity2.other_task.valid?, similarity2.errors.full_messages

    assert_not_nil similarity1.other_student, "Similarity1 'other_student' is nil"
    assert_not_nil similarity2.other_student, "Similarity2 'other_student' is nil"

    assert similarity1.other_student.valid?, similarity1.errors.full_messages
    assert similarity2.other_student.valid?, similarity2.errors.full_messages

    assert_equal similarity1.other_task_id, similarity2.task_id
    assert_equal similarity2.other_task_id, similarity1.task_id

    assert_equal 100, similarity1.pct
    assert_equal 100, similarity2.pct

    assert td.has_jplag_report?, "Expected task definition to have a JPlag report"

    # Create a similarity below the threshold
    similarity1 = JplagTaskSimilarity.create(
      task: student1_task,
      other_task: student2_task,
      pct: 10,
      flagged: true
    )

    # Create a similarity above the threshold
    similarity2 = JplagTaskSimilarity.create(
      task: student1_task,
      other_task: student2_task,
      pct: 99,
      flagged: true
    )

    unit.check_jplag_similarity(force: true)

    assert_not JplagTaskSimilarity.exists?(similarity1.id), "Similarity with lower threshold whould have been deleted"
    assert JplagTaskSimilarity.exists?(similarity2.id), "Similarity with higher threshold should not have been deleted"

    JplagTaskSimilarity.delete_all

    # Test JPlag base code: reuse the same file so previous similarity matches are ignored

    java_file = Rails.root.join("test_files/submissions/jplag/Angry Coyote/sociologia.java")
    zip_path = Rails.root.join("tmp/resources/resources.zip")
    FileUtils.mkdir_p(zip_path.dirname)

    Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
      zipfile.add(File.basename(java_file), java_file)
    end

    td.add_task_resources(zip_path, copy: false)

    assert td.has_task_resources?

    td.update(use_resources_for_jplag_base_code: true)

    unit.check_jplag_similarity(force: true)

    similarity1 = JplagTaskSimilarity.find_by(task_id: student1_task.id)
    similarity2 = JplagTaskSimilarity.find_by(task_id: student2_task.id)

    assert_nil similarity1, "JPlag base code should have been used to ignore similarity"
    assert_nil similarity2, "JPlag base code should have been used to ignore similarity"
  end

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
