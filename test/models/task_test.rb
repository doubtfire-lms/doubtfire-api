require 'test_helper'
require 'pdf-reader'

#
# Contains tests for Task model objects - not accessed via API
#
class TaskTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::TestFileHelper
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include ActiveSupport::Testing::TimeHelpers

  def error!(msg, _code)
    raise StandardError, msg
  end

  def clear_submission(task)
    FileUtils.rm_rf(FileHelper.student_work_dir(:new, task, false))
    FileUtils.rm_rf(FileHelper.student_work_dir(:in_process, task, false))
  end

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

  def test_add_text_comment_with_raw_utf8_emoji_bytes
    project = FactoryBot.create(:project)
    unit = project.unit
    convenor = unit.main_convenor_user
    task_definition = unit.task_definitions.first
    task = project.task_for_task_definition(task_definition)
    comment_text = "\xF0\x9F\x98\x82".force_encoding(Encoding::UTF_8)

    comment = task.add_text_comment(convenor, comment_text)

    assert comment.persisted?
    assert_equal comment_text, comment.comment
    assert_equal comment_text, TaskComment.find(comment.id).read_attribute(:comment)
  end

  def test_trigger_transition_allows_assessment_outcomes_without_feedback_check_by_default
    project = FactoryBot.create(:project)
    unit = project.unit
    task_definition = unit.task_definitions.first
    task = project.task_for_task_definition(task_definition)
    tutor = unit.main_convenor_user

    task.update!(task_status: TaskStatus.ready_for_feedback)
    task.add_status_comment(project.student, TaskStatus.ready_for_feedback)

    assert task.trigger_transition(trigger: 'complete', by_user: tutor)
    assert_equal TaskStatus.complete, task.task_status
  end

  def test_trigger_transition_requires_manual_feedback_before_assessment_outcomes_when_checking_feedback
    project = FactoryBot.create(:project)
    unit = project.unit
    task_definition = unit.task_definitions.first
    task = project.task_for_task_definition(task_definition)
    tutor = unit.main_convenor_user

    task.update!(task_status: TaskStatus.ready_for_feedback)
    task.add_status_comment(project.student, TaskStatus.ready_for_feedback)

    assert_nil task.trigger_transition(trigger: 'complete', by_user: tutor, check_feedback: true)
    assert_equal TaskStatus.ready_for_feedback, task.task_status
    assert_includes task.errors.full_messages.to_sentence, 'until feedback has been given'

    task.reload
    task.add_text_comment(project.student, 'Student follow-up')

    assert_nil task.trigger_transition(trigger: 'fix', by_user: tutor, check_feedback: true)
    assert_equal TaskStatus.ready_for_feedback, task.task_status

    task.reload
    task.add_text_comment(tutor, '**Automated Message:** Automated feedback is not enough')

    assert_nil task.trigger_transition(trigger: 'redo', by_user: tutor, check_feedback: true)
    assert_equal TaskStatus.ready_for_feedback, task.task_status

    task.reload
    task.add_text_comment(tutor, 'Manual tutor feedback')

    assert task.trigger_transition(trigger: 'complete', by_user: tutor, check_feedback: true)
    assert_equal TaskStatus.complete, task.task_status
  end

  def test_trigger_transition_requires_recent_manual_tutor_feedback_for_fix_and_redo_when_checking_feedback
    travel_to Time.zone.parse('2026-05-13 10:00:00 UTC') do
      project = FactoryBot.create(:project)
      unit = project.unit
      task_definition = unit.task_definitions.first
      task = project.task_for_task_definition(task_definition)
      tutor = unit.main_convenor_user

      task.update!(task_status: TaskStatus.ready_for_feedback)
      task.add_status_comment(project.student, TaskStatus.ready_for_feedback)
      task.add_text_comment(tutor, 'Older manual tutor feedback').update!(created_at: 11.minutes.ago)

      assert_nil task.trigger_transition(trigger: 'fix', by_user: tutor, check_feedback: true)
      assert_equal TaskStatus.ready_for_feedback, task.task_status

      task.reload
      task.add_text_comment(tutor, 'Recent manual tutor feedback')

      assert task.trigger_transition(trigger: 'fix', by_user: tutor, check_feedback: true)
      assert_equal TaskStatus.fix_and_resubmit, task.task_status

      task.update!(task_status: TaskStatus.ready_for_feedback)
      task.add_text_comment(tutor, 'Recent manual tutor feedback for redo')

      assert task.trigger_transition(trigger: 'redo', by_user: tutor, check_feedback: true)
      assert_equal TaskStatus.redo, task.task_status
    end
  end

  def test_days_awaiting_feedback_pauses_during_break
    travel_to Time.zone.parse('2026-04-10 00:00:00 UTC') do
      teaching_period = FactoryBot.create(
        :teaching_period,
        start_date: Time.zone.parse('2026-03-01 00:00:00 UTC'),
        end_date: Time.zone.parse('2026-04-30 00:00:00 UTC'),
        active_until: Time.zone.parse('2026-05-31 00:00:00 UTC')
      )
      teaching_period.add_break(Time.zone.parse('2026-04-01 00:00:00 UTC'), 2)

      unit = FactoryBot.create(:unit, teaching_period: teaching_period, with_students: false)
      task = FactoryBot.create(:task, project: FactoryBot.create(:project, unit: unit))
      task.update!(submission_date: Time.zone.parse('2026-03-29 00:00:00 UTC'))

      assert_equal 3.0, task.days_awaiting_feedback
      assert_equal 12.0, task.calendar_days_awaiting_feedback
    end
    travel_back
  end

  def test_days_awaiting_feedback_resumes_after_break
    travel_to Time.zone.parse('2026-04-18 00:00:00 UTC') do
      teaching_period = FactoryBot.create(
        :teaching_period,
        start_date: Time.zone.parse('2026-03-01 00:00:00 UTC'),
        end_date: Time.zone.parse('2026-04-30 00:00:00 UTC'),
        active_until: Time.zone.parse('2026-05-31 00:00:00 UTC')
      )
      teaching_period.add_break(Time.zone.parse('2026-04-01 00:00:00 UTC'), 2)

      unit = FactoryBot.create(:unit, teaching_period: teaching_period, with_students: false)
      task = FactoryBot.create(:task, project: FactoryBot.create(:project, unit: unit))
      task.update!(submission_date: Time.zone.parse('2026-03-29 00:00:00 UTC'))

      assert_equal 6.0, task.days_awaiting_feedback
    end
    travel_back
  end

  def test_days_awaiting_feedback_stays_at_zero_for_submissions_made_during_break
    travel_to Time.zone.parse('2026-04-10 00:00:00 UTC') do
      teaching_period = FactoryBot.create(
        :teaching_period,
        start_date: Time.zone.parse('2026-03-01 00:00:00 UTC'),
        end_date: Time.zone.parse('2026-04-30 00:00:00 UTC'),
        active_until: Time.zone.parse('2026-05-31 00:00:00 UTC')
      )
      teaching_period.add_break(Time.zone.parse('2026-04-01 00:00:00 UTC'), 2)

      unit = FactoryBot.create(:unit, teaching_period: teaching_period, with_students: false)
      task = FactoryBot.create(:task, project: FactoryBot.create(:project, unit: unit))
      task.update!(submission_date: Time.zone.parse('2026-04-05 00:00:00 UTC'))

      assert_equal 0.0, task.days_awaiting_feedback
    end
    travel_back
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
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    td.destroy
    assert_not File.exist? path
  end

  def test_pdf_creation_with_code_csv_and_gif_has_stable_last_page_footer
    unit = Unit.first
    td = TaskDefinition.new({
                              unit_id: unit.id,
                              tutorial_stream: unit.tutorial_streams.first,
                              name: 'Task with code and image',
                              description: 'Code and image task',
                              weighting: 4,
                              target_grade: 0,
                              start_date: unit.start_date + 1.week,
                              target_date: unit.start_date + 2.weeks,
                              abbreviation: 'TaskPdfWithCodeCsvAndGif',
                              restrict_status_updates: false,
                              upload_requirements: [
                                { "key" => 'file0', "name" => 'Code file', "type" => 'code' },
                                { "key" => 'file1', "name" => 'An Image', "type" => 'image' }
                              ],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0
                            })
    td.save!

    data_to_post = with_files(
      [
        { path: 'test_files/COS10001-ImportTasksWithTutorialStream.csv', type: 'text/csv' },
        { path: 'test_files/submissions/unbelievable.gif', type: 'image/gif' }
      ],
      { trigger: 'ready_for_feedback' }
    )

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    reader = PDF::Reader.new(task.final_pdf_path)

    assert_equal 6, reader.pages.count # 1 cover page + 5 pages
    assert_includes reader.pages.last.text.gsub(/\s+/, ' '), 'Page 5 of 5'

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
    assert task.convert_submission_to_pdf(log_to_stdout: true)
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

    task.convert_submission_to_pdf(log_to_stdout: false)

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

    project = unit.active_projects.first

    # Check we can't auto generate if we do not have a learning summary report
    refute project.learning_summary_report_exists?
    refute project.auto_generate_portfolio
    refute project.compile_portfolio
    refute project.portfolio_auto_generated

    path = File.join(project.portfolio_temp_path, '000-document-LearningSummaryReport.pdf')
    refute File.exist? path

    data_to_post = with_file('test_files/unit_files/sample-learning-summary.pdf', 'application/pdf', data_to_post)

    add_auth_header_for user: project.user

    post "/api/projects/#{project.id}/task_def_id/#{task_def.id}/submission", data_to_post

    assert_equal 201, last_response.status

    project_task = project.task_for_task_definition(task_def)

    # Check if file exists in :new
    assert project_task.processing_pdf?

    # Generate pdf for task
    assert project_task.convert_submission_to_pdf(log_to_stdout: false)

    # Check if pdf was copied over
    project.reload
    assert project.uses_draft_learning_summary
    assert File.exist? path
    assert project.learning_summary_report_exists?

    # Check we can auto generate
    project.auto_generate_portfolio
    assert project.compile_portfolio
    assert project.portfolio_auto_generated

    project.compile_portfolio = false
    project.portfolio_auto_generated = false
    project.save

    # Check auto generate doesn't work if we are not enrolled
    project.enrolled = false
    refute project.auto_generate_portfolio
    refute project.compile_portfolio
    refute project.portfolio_auto_generated

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
    assert project_task.convert_submission_to_pdf(log_to_stdout: false)

    # Check if the file was moved to portfolio
    assert_not project.uses_draft_learning_summary

    unit.destroy
    assert_not File.exist? path
  end

  def test_ipynb_to_pdf
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task with ipynb',
        description: 'Code task',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'TaskPdfWithIpynb',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'A notebook', "type" => 'code' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/vectorial_graph.ipynb', 'application/json', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    # Test if latex math was rendered properly
    reader = PDF::Reader.new(task.final_pdf_path)

    # PDF-reader incorrectly parses "weight (kg) / height (m)^2" as "weight (2g) / height (m)", misplacing the ^2
    # Detecting "height" and "weight" confirms correct LaTeX rendering
    assert reader.pages.last.text.include?("BMI: bmi ="), reader.pages.last.text
    assert reader.pages.last.text.include?("weight")
    assert reader.pages.last.text.include?("height (m)")

    # ensure the notice is not included when the notebook doesn't have long lines source code cells
    # and no errors
    reader.pages.each do |page|
      assert_not page.text.include? 'The rest of this line has been truncated by the system to improve readability.'
      assert_not page.text.include?('ERROR when parsing'), page.text
    end

    # test line wrapping in jupynotex
    data_to_post = with_file('test_files/submissions/long.ipynb', 'application/json', data_to_post)

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    # test submission generation
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    # ensure the notice is included when the notebook has long line in source code cells
    reader = PDF::Reader.new(task.final_pdf_path)
    assert reader.pages[1].text.gsub(/\s+/, " ").include? "[The rest of this line has been truncated by the system to improve readability.]"

    # test excessive long raw data
    data_to_post = with_file('test_files/submissions/many_lines.ipynb', 'application/json', data_to_post)
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    # test submission generation
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    # ensure the notice is included when the notebook has long line in source code cells
    reader = PDF::Reader.new(task.final_pdf_path)

    assert_equal 4, reader.pages.count

    td.destroy
    assert_not File.exist? path
    unit.destroy!
  end

  def test_code_submission_with_long_lines
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task with super ling lines in code submission',
        description: 'Code task',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'Long',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'long.py', "type" => 'code' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/long.py', 'application/json', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    # test submission generation
    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    # ensure the notice is included when rendered files are truncated
    reader = PDF::Reader.new(task.final_pdf_path)
    assert reader.pages[1].text.include? "This file has additional line breaks applied"

    # submit a normal file and ensure the notice is not included in the PDF
    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/normal.py', 'application/json', data_to_post)
    project = unit.active_projects.first
    add_auth_header_for user: unit.main_convenor_user
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status, last_response_body

    # test submission generation
    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    # ensure the notice is not included
    reader = PDF::Reader.new(task.final_pdf_path)
    assert_not reader.pages[1].text.include? "This file has additional line breaks applied"

    td.destroy
    assert_not File.exist? path
    unit.destroy!
  end

  def test_code_submission_with_long_lines
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task with super ling lines in code submission',
        description: 'Code task',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'Long',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'long.py', "type" => 'code' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/long.py', 'application/json', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    # test submission generation
    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    # ensure the notice is included when rendered files are truncated
    reader = PDF::Reader.new(task.final_pdf_path)
    assert reader.pages[1].text.include? "This file has additional line breaks applied"

    # submit a normal file and ensure the notice is not included in the PDF
    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/normal.py', 'application/json', data_to_post)
    project = unit.active_projects.first
    add_auth_header_for user: unit.main_convenor_user
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status, last_response_body

    # test submission generation
    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    # ensure the notice is not included
    reader = PDF::Reader.new(task.final_pdf_path)
    assert_not reader.pages[1].text.include? "This file has additional line breaks applied"

    td.destroy
    assert_not File.exist? path
    unit.destroy!
  end

  def test_code_submission_with_long_lines
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Task with super ling lines in code submission',
        description: 'Code task',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'Long',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'long.py', "type" => 'code' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/long.py', 'application/json', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    # test submission generation
    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    # ensure the notice is included when rendered files are truncated
    reader = PDF::Reader.new(task.final_pdf_path)
    assert reader.pages[1].text.include? "This file has additional line breaks applied"

    # submit a normal file and ensure the notice is not included in the PDF
    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/normal.py', 'application/json', data_to_post)
    project = unit.active_projects.first
    add_auth_header_for user: unit.main_convenor_user
    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post
    assert_equal 201, last_response.status, last_response_body

    # test submission generation
    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    # ensure the notice is not included
    reader = PDF::Reader.new(task.final_pdf_path)
    assert_not reader.pages[1].text.include? "This file has additional line breaks applied"

    td.destroy
    assert_not File.exist? path
    unit.destroy!
  end

  def test_pdf_validation_on_submit
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'PDF Test Task',
        description: 'Test task',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'PDFTestTask',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'A pdf file', "type" => 'document' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    # submit an encrypted (but valid) PDF file and ensure it's rejected immediately
    data_to_post = with_file('test_files/submissions/encrypted.pdf', 'application/json', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 403, last_response.status, last_response_body

    # submit a corrupted PDF file and ensure it's rejected immediately
    data_to_post = with_file('test_files/submissions/corrupted.pdf', 'application/json', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 403, last_response.status, last_response_body

    # submit a valid PDF file and ensure it's accepted
    data_to_post = with_file('test_files/submissions/valid.pdf', 'application/json', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    td.destroy
    assert_not File.exist? path
    unit.destroy!
  end

  def test_pdf_creation_fails_on_invalid_pdf
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'PDF Test Task',
        description: 'Test task',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'PDFTestTask',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'A pdf file', "type" => 'code' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    project = unit.active_projects.first

    task = project.task_for_task_definition(td)

    folder = FileHelper.student_work_dir(:new, task)

    # Copy the file in
    FileUtils.cp(Rails.root.join('test_files/submissions/corrupted.pdf'), "#{folder}/001-code.cs")

    begin
      assert_not task.convert_submission_to_pdf(log_to_stdout: false)
    rescue StandardError => e
      task.reload

      assert_equal 2, task.comments.count
      assert task.comments.last.comment.starts_with?('**Automated Comment**:')
      assert task.comments.last.comment.include?(e.message.to_s)

      td.destroy
      unit.destroy!
    end
  end

  def test_pax_crash_does_not_stop_pdf_creation
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'PDF Test Task',
        description: 'Test task',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'PDFTestTask',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'A pdf file', "type" => 'document' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    # submit an encrypted (but valid) PDF file and ensure it's rejected immediately
    data_to_post = with_file('test_files/submissions/valid.pdf', 'application/json', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    task = project.task_for_task_definition(td)

    rails_latex_path = Rails.root.join("tmp/rails-latex/#{Process.pid}-#{Thread.current.hash}")
    FileUtils.mkdir_p(rails_latex_path)
    FileUtils.cp(Rails.root.join('test_files/latex/input-broken.aux'), "#{rails_latex_path}/input.aux")

    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    td.destroy
    assert_not File.exist? path
    unit.destroy!
  end

  def test_accept_files_checks_they_all_exist
    project = FactoryBot.create(:project)
    unit = project.unit
    user = project.student
    # convenor = unit.main_convenor_user
    task_definition = unit.task_definitions.first

    task_definition.start_date = Time.zone.now - 1.week
    task_definition.target_date = Time.zone.now + 1.day
    task_definition.due_date = Time.zone.now + 1.week
    task_definition.target_grade = 0
    task_definition.upload_requirements = [
      {
        "key" => 'file0',
        "name" => 'Document 1',
        "type" => 'document'
      },
      {
        "key" => 'file1',
        "name" => 'Document 2',
        "type" => 'document'
      },
      {
        "key" => 'file2',
        "name" => 'Code 1',
        "type" => 'code'
      },
      {
        "key" => 'file3',
        "name" => 'Document 3',
        "type" => 'document'
      },
      {
        "key" => 'file4',
        "name" => 'Document 4',
        "type" => 'document'
      }
    ]

    # Saving task def
    task_definition.save!
    task_definition.reload

    # Test that the task def is setup correctly
    assert_equal 5, task_definition.number_of_uploaded_files

    # Now... lets upload a submission
    task = project.task_for_task_definition(task_definition)

    # Create a submission - but no files!
    begin
      task.accept_submission user, [], self, nil, 'ready_for_feedback', nil
      assert false, 'Should have raised an error with no files submitted'
    rescue StandardError
      assert_equal :not_started, task.status
    end

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
      }
    ], self, nil, 'ready_for_feedback', nil, accepted_tii_eula: true

    task.reload
    assert_equal :ready_for_feedback, task.status

    task_definition.upload_requirements = []
    task_definition.save!

    task.task_status = TaskStatus.not_started
    task.save!
    task.reload

    clear_submission(task)

    # Now... lets upload a submission with no files
    task.accept_submission user, [], self, nil, 'ready_for_feedback', nil
    assert_equal :ready_for_feedback, task.status

    task.task_status = TaskStatus.not_started
    task.save!

    # Now... lets upload a submission with too many files
    begin
      task.accept_submission user,
        [
          {
            id: 'file0',
            name: 'Document 1',
            type: 'document',
            filename: 'file0.pdf',
            "tempfile" => File.new(test_file_path('submissions/1.2P.pdf'))
          }
        ], self, nil, 'ready_for_feedback', nil
      assert false, 'Should have raised an error with too many files submitted'
    rescue StandardError => e
      assert_equal :not_started, task.status
    end
  end

  def test_cannot_upload_with_existing_upload_in_process
    project = FactoryBot.create(:project)
    unit = project.unit
    user = project.student
    convenor = unit.main_convenor_user
    task_definition = unit.task_definitions.first

    task_definition.upload_requirements = [
      {
        "key" => 'file0',
        "name" => 'Document 1',
        "type" => 'document'
      }
    ]

    task_definition.target_date = Time.zone.now + 1.day
    task_definition.due_date = task_definition.target_date + 1.week

    # Saving task def
    task_definition.save!

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
      }
    ], self, nil, 'ready_for_feedback', nil, accepted_tii_eula: true

    assert_equal :ready_for_feedback, task.status

    # Now... try uploading again
    begin
      task.accept_submission user,
        [
          {
            id: 'file0',
            name: 'Document 1',
            type: 'document',
            filename: 'file0.pdf',
            "tempfile" => File.new(test_file_path('submissions/1.2P.pdf'))
          }
        ], self, nil, 'ready_for_feedback', nil
      assert false, 'Should have raised an error with existing upload in process'
    rescue StandardError => e
      assert_includes e.message, 'A submission is already being processed. Please wait for the current submission process to complete.'
      assert_equal :ready_for_feedback, task.status
    end

    FileHelper.move_files(FileHelper.student_work_dir(:new, task, false), FileHelper.student_work_dir(:in_process, task, false), false)

    begin
      task.accept_submission user,
        [
          {
            id: 'file0',
            name: 'Document 1',
            type: 'document',
            filename: 'file0.pdf',
            "tempfile" => File.new(test_file_path('submissions/1.2P.pdf'))
          }
        ], self, nil, 'ready_for_feedback', nil
      assert false, 'Should have raised an error with existing upload in process'
    rescue StandardError => e
      assert_includes e.message, 'A submission is already being processed. Please wait for the current submission process to complete.'
      assert_equal :ready_for_feedback, task.status
    end

    FileUtils.rm_rf(FileHelper.student_work_dir(:in_process, task, false))

    assert_not task.processing_pdf?

    # Create a submission
    task.accept_submission user, [
      {
        id: 'file0',
        name: 'Document 1',
        type: 'document',
        filename: 'file0.pdf',
        "tempfile" => File.new(test_file_path('submissions/1.2P.pdf'))
      }
    ], self, nil, 'ready_for_feedback', nil, accepted_tii_eula: true

    assert_equal :ready_for_feedback, task.status
  ensure
    unit.destroy
  end

  def test_check_files_on_task_move
    project = FactoryBot.create(:project)
    unit = project.unit
    user = project.student
    convenor = unit.main_convenor_user
    task_definition = unit.task_definitions.first

    task_definition.upload_requirements = [
      {
        "key" => 'file0',
        "name" => 'Document 1',
        "type" => 'document'
      }
    ]

    # Saving task def
    task_definition.save!

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
      }
    ], self, nil, 'ready_for_feedback', nil, accepted_tii_eula: true

    # Test that we can move to in process
    assert task.move_files_to_in_process
    assert_not File.exist? FileHelper.student_work_dir(:new, task, false)
    assert File.exist? FileHelper.student_work_dir(:in_process, task, false)

    # Test that we can move back to new
    FileHelper.move_files(FileHelper.student_work_dir(:in_process, task, false), FileHelper.student_work_dir(:new, task, false), false)
    assert File.exist? FileHelper.student_work_dir(:new, task, false)
    assert_not File.exist? FileHelper.student_work_dir(:in_process, task, false)

    # Delete a file and try to compress
    FileUtils.rm("#{FileHelper.student_work_dir(:new, task)}/000-document.pdf")

    assert_not task.compress_new_to_done

    FileHelper.student_work_dir(:new, task, true)
    assert_not task.move_files_to_in_process
  ensure
    unit.destroy
  end

  def test_portfolio_evidence_path
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    td = TaskDefinition.new({
        unit_id: unit.id,
        tutorial_stream: unit.tutorial_streams.first,
        name: 'Test task',
        description: 'Code task',
        weighting: 4,
        target_grade: 0,
        start_date: unit.start_date + 1.week,
        target_date: unit.start_date + 2.weeks,
        abbreviation: 'ABBR',
        restrict_status_updates: false,
        upload_requirements: [ { "key" => 'file0', "name" => 'Some Code', "type" => 'code' } ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      trigger: 'ready_for_feedback'
    }

    data_to_post = with_file('test_files/submissions/program.cs', 'application/json', data_to_post)

    project = unit.active_projects.first

    add_auth_header_for user: unit.main_convenor_user

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    assert_equal 201, last_response.status, last_response_body

    task = project.task_for_task_definition(td)
    assert task.convert_submission_to_pdf(log_to_stdout: true)
    path = task.zip_file_path_for_done_task
    assert path
    assert File.exist? path
    assert File.exist? task.final_pdf_path

    assert_nil task.portfolio_evidence

    new_path = task.final_pdf_path.gsub(/\.pdf$/, '-evidence.pdf')

    FileUtils.mv task.final_pdf_path(ignore_portfolio_evidence: true), new_path

    task.portfolio_evidence = new_path.gsub(/#{FileHelper.student_work_root}/, '')
    task.save

    assert_equal new_path, task.final_pdf_path
    assert_not_equal new_path, task.final_pdf_path(ignore_portfolio_evidence: true)

    assert_not File.exist?(task.final_pdf_path(ignore_portfolio_evidence: true))
    assert File.exist?(task.final_pdf_path)

    user = project.student
    user.update(username: 'student')
    task.reload
    assert File.exist?(task.final_pdf_path), "File does not exist #{task.final_pdf_path}"

    td.update(abbreviation: 'ABBR2')
    task.reload
    assert_not_equal new_path, task.final_pdf_path
    assert File.exist?(task.final_pdf_path)
    assert File.exist?(task.final_pdf_path(ignore_portfolio_evidence: true))

    # Rename again...
    new_path = task.final_pdf_path.gsub(/\.pdf$/, '-evidence.pdf')
    FileUtils.mv task.final_pdf_path, new_path
    task.portfolio_evidence = new_path.gsub(/#{FileHelper.student_work_root}/, '')
    task.save

    post "/api/projects/#{project.id}/task_def_id/#{td.id}/submission", data_to_post

    # Check it has moved to the new path and removed the portfolio_evidence attribute
    task.reload
    assert_nil task.portfolio_evidence
    assert_not File.exist?(new_path), "File exists #{new_path} after upload"
    task.convert_submission_to_pdf(log_to_stdout: false)
    assert File.exist?(task.final_pdf_path), task.final_pdf_path

    # Check after archive

    # Rename again...
    new_path = task.final_pdf_path.gsub(/\.pdf$/, '-evidence.pdf')
    FileUtils.mv task.final_pdf_path, new_path
    task.portfolio_evidence = new_path.gsub(/#{FileHelper.student_work_root}/, '')
    task.save

    # Move to archive
    unit.move_files_to_archive

    # Check it has moved to the new path and removed the portfolio_evidence attribute
    task.reload
    assert task.portfolio_evidence.present?
    assert_not File.exist?(new_path)
    assert File.exist?(task.final_pdf_path), "File does not exist #{task.final_pdf_path} after archive"

    td.destroy
    unit.destroy
  end

  def test_extension_on_trigger_transition
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0, start_date: Time.zone.now - 3.days, end_date: Time.zone.now + 10.weeks)
    unit.allow_student_extension_requests = true
    unit.extension_weeks_on_resubmit_request = 1
    unit.save!

    td = TaskDefinition.new({
                              unit_id: unit.id,
                              tutorial_stream: unit.tutorial_streams.first,
                              name: 'Test task',
                              description: 'Test task',
                              weighting: 4,
                              target_grade: 0,
                              start_date: unit.start_date,
                              target_date: unit.start_date + 1.week,
                              abbreviation: 'ABBR',
                              restrict_status_updates: false,
                              upload_requirements: [ ],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0
                            })
    td.save!

    project = unit.active_projects.first
    task = project.task_for_task_definition(td)

    task.trigger_transition(trigger: 'fix', by_user: unit.main_convenor_user)
    assert_equal :fix_and_resubmit, task.status, "Task status should be 'fix' after trigger transition"
    assert_equal 1, task.reload.extensions

    # Check that trigger to 'ready_for_feedback' accepts when before due date
    task.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    assert_equal :ready_for_feedback, task.status, 'Task status should be "ready_for_feedback" after trigger transition'

    task.destroy!

    unit.allow_flexible_dates = true
    unit.save!
    task = project.task_for_task_definition(td)

    # Extensions are not added when flexible dates are enabled
    task.trigger_transition(trigger: 'fix', by_user: unit.main_convenor_user)
    assert_equal :fix_and_resubmit, task.status, 'Task status should be "fix" after trigger transition'
    assert_equal 0, task.reload.extensions

    # Check that trigger to 'ready_for_feedback' accepts when before deadline in flexible dates mode
    task.extensions = -2
    task.save!

    task.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    assert_equal :ready_for_feedback, task.status, 'Task status should be "ready_for_feedback" after trigger transition'

    unit.destroy!
  end

  def test_trigger_time_exceeded
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0, start_date: Time.zone.now - 3.weeks, end_date: Time.zone.now + 10.weeks)
    unit.allow_student_extension_requests = true
    unit.extension_weeks_on_resubmit_request = 1
    unit.save!

    td = TaskDefinition.new({
                              unit_id: unit.id,
                              tutorial_stream: unit.tutorial_streams.first,
                              name: 'Test task',
                              description: 'Test task',
                              weighting: 4,
                              target_grade: 0,
                              start_date: Time.zone.now - 3.week,
                              target_date: Time.zone.now - 2.week,
                              due_date: Time.zone.now + 1.week,
                              abbreviation: 'ABBR',
                              restrict_status_updates: false,
                              upload_requirements: [ ],
                              plagiarism_warn_pct: 0.8,
                              is_graded: false,
                              max_quality_pts: 0
                            })
    td.save!

    project = unit.active_projects.first
    task = project.task_for_task_definition(td)

    # Test time exceeded when submitted after the due date
    task.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    assert_equal :time_exceeded, task.status, 'Task status should be "time_exceeded" after trigger transition'

    # Extensions from target to due... mean we can submit
    task.extensions = 2
    task.save!
    task.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    assert_equal :ready_for_feedback, task.status, 'Task status should be "time_exceeded" after trigger transition'

    # Clear task and test with flexible dates
    task.destroy!
    unit.allow_flexible_dates = true
    unit.save!

    task = project.task_for_task_definition(td)

    # Test not time exceeded when submitted after target date... as deadline always in play
    task.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    assert_equal :ready_for_feedback, task.status, 'Task status should be "ready_for_feedback" - despite after target date'

    # Adjust the due date...
    td.due_date = Time.zone.now - 2.days
    td.save!

    task.update!(submission_date: nil, task_status: TaskStatus.not_started) # If there was a previous submission then it would stay on ready for feedback, so we need to reset it
    task.reload

    task.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    assert_equal :time_exceeded, task.status, 'Task status should be "time_exceeded" - after deadline'

    # Check that spec_con_days is respected - should extend the due date by 3 days
    project.spec_con_days = 3
    project.save!
    task.reload

    task.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    assert_equal :ready_for_feedback, task.status, 'Task status should be "ready_for_feedback" - due to spec con days'
  end

  def test_assessment_lock_to_tutorial_stream
    # unit = FactoryBot.create(:unit, student_count: 1, task_count: 0, stream_count: 0, tutorials: 0)
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)

    tutorial_stream_main = FactoryBot.create(:tutorial_stream, unit: unit)
    # tutorial_stream_main2 = FactoryBot.create(:tutorial_stream, unit: unit)
    tutorial_stream_hd = FactoryBot.create(:tutorial_stream, unit: unit)

    tutor1 = FactoryBot.create(:user, :tutor)
    tutor2 = FactoryBot.create(:user, :tutor)

    # Unit role 1 will only have a tutorial in Main
    # This means they shouldnt be allowed to assess tasks in the HD tutorial stream
    unit_role1 = unit.employ_staff(tutor1, Role.tutor)

    # Unit role 2 will have a tutorial in both Main and HD
    # This means they should be allowed to assess tasks in both the Main and HD tutorial streams
    unit_role2 = unit.employ_staff(tutor2, Role.tutor)

    tutorial_main1 = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_main, unit_role: unit_role1)
    tutorial_main2 = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_main, unit_role: unit_role2)
    tutorial_hd = FactoryBot.create(:tutorial, unit: unit, tutorial_stream: tutorial_stream_hd, unit_role: unit_role2)

    td1 = TaskDefinition.new({
                               unit_id: unit.id,
                               tutorial_stream: tutorial_stream_main,
                               name: 'Test task for main',
                               description: 'Test task',
                               weighting: 4,
                               target_grade: 0,
                               start_date: Time.zone.now - 3.weeks,
                               target_date: Time.zone.now - 2.weeks,
                               due_date: Time.zone.now + 1.week,
                               abbreviation: 'ABBR1',
                               restrict_status_updates: false,
                               upload_requirements: [],
                               plagiarism_warn_pct: 0.8,
                               is_graded: false,
                               max_quality_pts: 0,
                               lock_assessments_to_tutorial_stream: false
                             })

    td2 = TaskDefinition.new({
                               unit_id: unit.id,
                               tutorial_stream: tutorial_stream_hd,
                               name: 'Test task for HD',
                               description: 'Test task',
                               weighting: 4,
                               target_grade: 3,
                               start_date: Time.zone.now - 3.weeks,
                               target_date: Time.zone.now - 2.weeks,
                               due_date: Time.zone.now + 1.week,
                               abbreviation: 'ABBR2',
                               restrict_status_updates: false,
                               upload_requirements: [],
                               plagiarism_warn_pct: 0.8,
                               is_graded: false,
                               max_quality_pts: 0,
                               lock_assessments_to_tutorial_stream: false
                             })
    td1.save!
    td2.save!

    project = unit.active_projects.first
    task_main = project.task_for_task_definition(td1)
    task_hd = project.task_for_task_definition(td2)

    task_main.update!(task_status: TaskStatus.ready_for_feedback)
    task_hd.update!(task_status: TaskStatus.ready_for_feedback)
    assert_equal TaskStatus.ready_for_feedback, task_main.task_status
    assert_equal TaskStatus.ready_for_feedback, task_hd.task_status

    # Tutor 1 should be able to mark main feedback task complete
    result = task_main.trigger_transition(trigger: 'complete', by_user: tutor1)
    assert_not_nil result, "Task should be able to marked complete by tutor"
    assert_equal TaskStatus.complete, task_main.task_status, 'Task status should be complete from tutor assessment'

    task_main.update!(task_status: TaskStatus.ready_for_feedback)
    td1.reload
    task_main.reload

    # Tutor 1 should be able to mark HD feedback task complete, even though its in another tutorial stream
    # Because we haven't locked it to the tutorial stream yet
    result = task_hd.trigger_transition(trigger: 'complete', by_user: tutor1)
    assert_not_nil result, "Task should be able to marked complete by tutor"
    assert_equal TaskStatus.complete, task_hd.task_status, 'Task status should be complete from tutor assessment'

    task_hd.update!(task_status: TaskStatus.ready_for_feedback)
    td2.update!(lock_assessments_to_tutorial_stream: true)
    td2.reload
    task_hd.reload

    # Tutor 1 should not be able to mark HD feedback task complete
    result = task_hd.trigger_transition(trigger: 'complete', by_user: tutor1)
    assert_nil result, "Task should not be able to marked complete by tutor"
    assert_equal TaskStatus.ready_for_feedback, task_hd.task_status, 'Tutor should not be able to mark HD task complete'

    task_hd.update!(task_status: TaskStatus.ready_for_feedback)
    td2.reload
    task_hd.reload
    # Tutor 2 should be able to mark HD feedback task complete
    result = task_hd.trigger_transition(trigger: 'complete', by_user: tutor2)
    assert_not_nil result, "Task should be able to marked complete by tutor"
    assert_equal TaskStatus.complete, task_hd.task_status, 'Task status should be complete from tutor assessment'
  end

  def test_prerequisite_tasks_change_to_fix_and_resubmit
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 4)
    tutor = FactoryBot.create(:user, :tutor)
    unit.employ_staff(tutor, Role.tutor)

    td1 = unit.task_definitions.first
    td2 = unit.task_definitions.second
    td3 = unit.task_definitions.third
    td4 = unit.task_definitions.fourth

    [td1, td2, td3, td4].each do |td|
      td.update!(start_date: Time.zone.now - 2.weeks, target_date: Time.zone.now + 2.weeks, due_date: Time.zone.now + 3.weeks, target_grade: 0)
    end

    TaskPrerequisite.create!(
      task_definition: td3,
      prerequisite: td2,
      task_status_id: TaskStatus.ready_for_feedback.id
    )

    TaskPrerequisite.create!(
      task_definition: td2,
      prerequisite: td1,
      task_status_id: TaskStatus.ready_for_feedback.id
    )

    project = unit.active_projects.first
    task1 = project.task_for_task_definition(td1)
    task2 = project.task_for_task_definition(td2)
    task3 = project.task_for_task_definition(td3)
    task4 = project.task_for_task_definition(td4)

    task1.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    task2.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    task3.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    task4.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    task1.reload
    task2.reload
    task3.reload
    task4.reload

    assert_equal TaskStatus.ready_for_feedback, task1.task_status
    assert_equal TaskStatus.ready_for_feedback, task2.task_status
    assert_equal TaskStatus.ready_for_feedback, task3.task_status
    assert_equal TaskStatus.ready_for_feedback, task4.task_status

    # Test case 1: Without recursive_fix, dependent tasks should not be affected
    task2.assess(TaskStatus.fix_and_resubmit, tutor)

    task1.reload
    task2.reload
    task3.reload
    task4.reload

    # Task 1 should not be affected, and recursive fixes should not run by default
    assert_equal TaskStatus.ready_for_feedback, task1.task_status, "Parent prerequisite should not be affected"
    assert_equal TaskStatus.fix_and_resubmit, task2.task_status, "Task should have updated to Fix and Resubmit"
    assert_equal TaskStatus.ready_for_feedback, task3.task_status, "Dependent task should not change without recursive_fix"
    assert_equal TaskStatus.ready_for_feedback, task4.task_status # Task 4 has no prerequsite links

    # Reset status
    task1.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    task2.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    task3.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    task4.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)

    task2.comments.delete_all

    task1.reload
    task2.reload
    task3.reload
    task4.reload

    # Test case 2: Ensure dependent tasks are recursively moved to fix and resubmit
    task1.assess(TaskStatus.fix_and_resubmit, tutor, Time.zone.now, true)

    task1.reload
    task2.reload
    task3.reload
    task4.reload

    assert_equal TaskStatus.fix_and_resubmit, task1.task_status, "Task should have updated to Fix and Resubmit"
    assert_equal TaskStatus.fix_and_resubmit, task2.task_status, "Dependent task should have automatically moved to Fix and Resubmit"
    assert_equal TaskStatus.fix_and_resubmit, task3.task_status, "Dependent task should have automatically moved to Fix and Resubmit"
    assert_equal TaskStatus.ready_for_feedback, task4.task_status # Task 4 has no prerequsite links

    lc = task2.comments.last
    assert_not lc.nil?, "Automated comment should have been created"
    assert lc.comment.start_with?("**Automated comment**: A prerequisite task")

    # Reset status
    task1.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    task2.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)
    task3.trigger_transition(trigger: 'complete', by_user: unit.main_convenor_user)
    task4.trigger_transition(trigger: 'ready_for_feedback', by_user: unit.main_convenor_user)

    task1.reload
    task2.reload
    task3.reload
    task4.reload

    # Test case 3: Ensure tasks that are not Ready for Feedback are not moved to Fix and resubmit
    task1.assess(TaskStatus.fix_and_resubmit, tutor, Time.zone.now, true)

    task1.reload
    task2.reload
    task3.reload
    task4.reload

    assert_equal TaskStatus.fix_and_resubmit, task1.task_status, "Task should have updated to Fix and Resubmit"
    assert_equal TaskStatus.fix_and_resubmit, task2.task_status, "Dependent task should have automatically moved to Fix and Resubmit"
    assert_equal TaskStatus.complete, task3.task_status, "Task not Ready for Feedback should not be affected"
    assert_equal TaskStatus.ready_for_feedback, task4.task_status # Task 4 has no prerequsite links
  end
end
