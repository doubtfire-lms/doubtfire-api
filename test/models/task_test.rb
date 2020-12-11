require 'test_helper'

#
# Contains tests for Task model objects - not accessed via API
#
class TaskDefinitionTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::TestFileHelper
  include TestHelpers::AuthHelper

  def app
    Rails.application
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
      trigger: 'ready_to_mark'
    }

    data_to_post = with_file('test_files/submissions/unbelievable.gif', 'image/gif', data_to_post)

    project = unit.active_projects.first

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", with_auth_token(data_to_post)

    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exists? path
    assert File.exists? task.final_pdf_path

    td.destroy
    assert_not File.exists? path
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
      trigger: 'ready_to_mark'
    }

    data_to_post = with_file('test_files/submissions/unbelievable.gif', 'image/gif', data_to_post)

    project = unit.active_projects.first

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", with_auth_token(data_to_post)

    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)
    task.move_files_to_in_process

    assert File.exists? "#{Doubtfire::Application.config.student_work_dir}/in_process/#{task.id}/000-image.jpg"

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
      trigger: 'ready_to_mark'
    }

    data_to_post = with_file('test_files/submissions/Swinburne.jpg', 'image/jpg', data_to_post)

    project = unit.active_projects.first

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", with_auth_token(data_to_post)

    assert_equal 201, last_response.status

    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exists? path
    assert File.exists? task.final_pdf_path

    td.destroy
    assert_not File.exists? path
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
      trigger: 'ready_to_mark'
    }

    data_to_post = with_file('test_files/submissions/Swinburne.jpg', 'image/jpg', data_to_post)

    project = unit.active_projects.first
    
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", with_auth_token(data_to_post)

    task = project.task_for_task_definition(td)
    
    task.convert_submission_to_pdf

    path = task.final_pdf_path
    assert File.exists? path

    td.destroy
    assert_not File.exists? path
  end

  def test_copy_draft_learning_summary
    unit = FactoryBot.create :unit, student_count:1, task_count:0
    task_def = FactoryBot.create(:task_definition, unit: unit, upload_requirements: [{'key' => 'file0','name' => 'Draft learning summary','type' => 'document'}])

    # Maybe make this call API to set
    unit.draft_task_definition = task_def
    unit.save

    data_to_post = {
      trigger: 'ready_to_mark'
    }

    data_to_post = with_file('test_files/unit_files/sample-learning-summary.pdf', 'application/pdf', data_to_post)

    project = unit.active_projects.first
    
    post "/api/projects/#{project.id}/task_def_id/#{task_def.id}/submission", with_auth_token(data_to_post, user=project.user)

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
    assert File.exists? path

    unit.destroy
    assert_not File.exists? path
  end

  def test_draft_learning_summary_wont_copy
    unit = FactoryBot.create :unit, student_count:1, task_count:0
    task_def = FactoryBot.create(:task_definition, unit: unit, upload_requirements: [{'key' => 'file0','name' => 'Draft learning summary','type' => 'document'}])

    unit.draft_task_definition = task_def

    project = unit.active_projects.first

    path = File.join(project.portfolio_temp_path, '000-document-LearningSummaryReport.pdf')
    FileUtils.mkdir_p(project.portfolio_temp_path)

    FileUtils.cp Rails.root.join('test_files/unit_files/sample-learning-summary.pdf'), path
    assert File.exists? path

    data_to_post = {
      trigger: 'ready_to_mark'
    }

    data_to_post = with_file('test_files/unit_files/sample-learning-summary.pdf', 'application/pdf', data_to_post)

    post "/api/projects/#{project.id}/task_def_id/#{task_def.id}/submission", with_auth_token(data_to_post, user=project.user)

    project_task = project.task_for_task_definition(task_def)

    # Check if file exists in :new
    assert project_task.processing_pdf?

    # Generate pdf for task
    assert project_task.convert_submission_to_pdf

    # Check if the file was moved to portfolio
    assert_not project.uses_draft_learning_summary

    unit.destroy
    assert_not File.exists? path
  end
end
