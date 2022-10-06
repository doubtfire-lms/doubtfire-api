require 'test_helper'

#
# Contains tests for Task model objects - not accessed via API
#
class TaskDefinitionTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::TestFileHelper
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_comments_for_user
    project = FactoryBot.create(:project)
    unit = project.unit
    user = project.student
    convenor = unit.main_convenor_user
    task_definition = unit.task_definitions.first
    task = project.task_for_task_definition(task_definition)

    task.add_text_comment(convenor, 'Hello World')
    task.add_text_comment(convenor, 'Message 2')
    task.add_text_comment(convenor, 'Last message')

    comments = task.comments_for_user(user)
    comments.each do |data|
      assert_equal 1, data.is_new
    end

    task.mark_comments_as_read user, task.comments

    comments = task.comments_for_user(user)
    comments.each do |data|
      assert_equal 0, data.is_new
    end
  end

  def test_pdf_creation_with_gif
    unit = Unit.first
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task with image',
        description: 'img task',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'TaskPdfWithGif',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'An Image', "type" => 'image' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/unbelievable.gif', 'image/gif', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    td.destroy
    assert_not File.exist? path
  end

  def test_image_upload
    unit = Unit.first
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task with image2',
        description: 'img task2',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'TaskPdfWithGif2',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'An Image', "type" => 'image' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/unbelievable.gif', 'image/gif', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)
    task.move_files_to_in_process(FileHelper.student_work_dir(:new))

    assert File.exist? "#{Doubtfire::Application.config.student_work_dir}/in_process/#{task.id}/000-image.jpg"

    td.destroy
  end

  def test_pdf_creation_with_jpg
    unit = Unit.first
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task with image',
        description: 'img task',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'TaskPdfWithJpg',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'An Image', "type" => 'image' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/Swinburne.jpg', 'image/jpg', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    td.destroy
    assert_not File.exist? path
  end

  def test_pdf_with_quotes_in_task_title
    unit = Unit.first
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: '"Quoted Task"',
        description: 'Task with quotes in name',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'TaskQuoted',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'An Image', "type" => 'image' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/Swinburne.jpg', 'image/jpg', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    task = project.task_for_task_definition(td)

    task.convert_submission_to_pdf

    path = task.final_pdf_path
    assert File.exist? path

    td.destroy
    assert_not File.exist? path
  end

  def test_copy_draft_learning_summary
    unit = FactoryBot.create :unit, student_count:1, task_count:0
    task_def = FactoryBot.create(:task_definition, unit: unit, upload_requirements: [{'key' => 'file0','name' => 'Draft learning summary','type' => 'document'}])

    # Maybe make this call API to set
    unit.draft_task_definition = task_def
    unit.save

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/unit_files/sample-learning-summary.pdf', 'application/pdf', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: project.user

    post "/api/projects/#{project.id}/task_def_id/#{task_def.id}/submission", data_to_post

    assert_equal 201, last_response.status

    project_task = project.task_for_task_definition(task_def)

    # Check if file exists in :new
    assert project_task.processing_pdf?

    # Generate pdf for task
    assert project_task.convert_submission_to_pdf

    # Check if pdf was copied over
    project.reload
    assert project.uses_draft_learning_summary
    path = File.join(project.portfolio_temp_path, '000-document-LearningSummaryReport.pdf')
    assert File.exist? path

    unit.destroy
    assert_not File.exist? path
  end

  def test_draft_learning_summary_wont_copy
    unit = FactoryBot.create :unit, student_count:1, task_count:0
    task_def = FactoryBot.create(:task_definition, unit: unit, upload_requirements: [{'key' => 'file0','name' => 'Draft learning summary','type' => 'document'}])

    unit.draft_task_definition = task_def

    project = unit.active_projects.first

    path = File.join(project.portfolio_temp_path, '000-document-LearningSummaryReport.pdf')
    FileUtils.mkdir_p(project.portfolio_temp_path)

    FileUtils.cp Rails.root.join('test_files/unit_files/sample-learning-summary.pdf'), path
    assert File.exist? path

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/unit_files/sample-learning-summary.pdf', 'application/pdf', data_to_post)

    add_auth_header_for user: project.user

    post "/api/projects/#{project.id}/task_def_id/#{task_def.id}/submission", data_to_post

    project_task = project.task_for_task_definition(task_def)

    # Check if file exists in :new
    assert project_task.processing_pdf?

    # Generate pdf for task
    assert project_task.convert_submission_to_pdf

    # Check if the file was moved to portfolio
    assert_not project.uses_draft_learning_summary

    unit.destroy
    assert_not File.exist? path
  end

  def test_grant_extension_days
    project = FactoryBot.create(:project)
    unit = project.unit
    user = project.student
    convenor = unit.main_convenor_user
    task_definition = unit.task_definitions.first
    task = project.task_for_task_definition(task_definition)

    # Test task due is task def due
    assert_equal task_definition.target_date, task.due_date

    task.grant_extension(convenor, 4) # 4 day extension
    assert_equal task_definition.target_date + 4.days, task.due_date
  end
end
