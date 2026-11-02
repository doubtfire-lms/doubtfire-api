require 'test_helper'

class NotebookShellProbeTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  PROOF_PATH = '/student-work/ontrack-notebook-shell-probe.txt'.freeze
  # Shared with the texlive container, like other students' work
  OUTSIDE_IMAGE_PATH = '/student-work/ontrack-notebook-image-probe.jpeg'.freeze

  def app
    Rails.application
  end

  def test_student_notebook_output_cannot_run_shell_command_during_pdf_generation
    FileUtils.rm_f(PROOF_PATH)
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    task = submit_notebook(unit, 'test_files/submissions/notebook_shell_probe.ipynb')

    assert task.convert_submission_to_pdf(log_to_stdout: false)
    assert_not File.exist?(PROOF_PATH)
  ensure
    FileUtils.rm_f(PROOF_PATH)
    unit&.destroy
  end

  def test_student_notebook_markdown_cannot_embed_files_outside_its_attachments
    FileUtils.cp('test_files/submissions/Deakin_Logo.jpeg', OUTSIDE_IMAGE_PATH)
    unit = FactoryBot.create(:unit, student_count: 1, task_count: 0)
    task = submit_notebook(unit, 'test_files/submissions/notebook_image_probe.ipynb')

    assert task.convert_submission_to_pdf(log_to_stdout: false)

    # The image syntax is shown as text instead of pulling the file into the PDF
    reader = PDF::Reader.new(task.final_pdf_path)
    assert reader.pages.last.text.include?('notebook-image-probe'), reader.pages.last.text

    # The title page logo is the only image allowed
    notebook_images = reader.pages.drop(1).sum do |page|
      page.xobjects.values.count { |xobject| xobject.hash[:Subtype] == :Image }
    end
    assert_equal 0, notebook_images
  ensure
    FileUtils.rm_f(OUTSIDE_IMAGE_PATH)
    unit&.destroy
  end

  private

  def submit_notebook(unit, notebook_path)
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
         with_file(notebook_path, 'application/json', trigger: 'ready_for_feedback')

    assert_equal 201, last_response.status, last_response_body
    project.task_for_task_definition(task_definition)
  end
end
