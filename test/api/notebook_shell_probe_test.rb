require 'test_helper'

class NotebookShellProbeTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  PROOF_PATH = '/student-work/ontrack-notebook-shell-probe.txt'.freeze

  def app
    Rails.application
  end

  def test_student_notebook_output_cannot_run_shell_command_during_pdf_generation
    FileUtils.rm_f(PROOF_PATH)
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    task_definition = TaskDefinition.create!(
      unit_id: unit.id,
      tutorial_stream: unit.tutorial_streams.first,
      name: 'Notebook command probe',
      description: 'Code task',
      weighting: 4,
      target_grade: 0,
      start_date: Time.zone.now - 2.weeks,
      target_date: Time.zone.now + 1.week,
      abbreviation: 'NotebookShellProbe',
      restrict_status_updates: false,
      upload_requirements: [{ 'key' => 'file0', 'name' => 'Notebook', 'type' => 'code' }],
      plagiarism_warn_pct: 0.8,
      is_graded: true,
      max_quality_pts: 0
    )

    project = unit.active_projects.first
    add_auth_header_for(user: project.user)
    post "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/submission",
         with_file('test_files/submissions/notebook_shell_probe.ipynb', 'application/json', trigger: 'ready_for_feedback')

    assert_equal 201, last_response.status, last_response_body
    task = project.task_for_task_definition(task_definition)
    assert task.convert_submission_to_pdf(log_to_stdout: false)
    assert_not File.exist?(PROOF_PATH)
  ensure
    FileUtils.rm_f(PROOF_PATH)
    unit&.destroy
  end
end
