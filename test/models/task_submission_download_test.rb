require 'test_helper'

class TaskSubmissionDownloadTest < ActiveSupport::TestCase
  def test_individual_and_bulk_downloads_use_upload_requirement_names
    project = FactoryBot.create(:project)
    unit = project.unit
    task_definition = unit.task_definitions.first
    task_definition.update!(upload_requirements: [
      { 'key' => 'file0', 'name' => 'Design report', 'type' => 'document' },
      { 'key' => 'file1', 'name' => 'source.py', 'type' => 'code' }
    ])
    task = project.task_for_task_definition(task_definition)
    source = task.zip_file_path_for_done_task
    FileUtils.mkdir_p(File.dirname(source))

    Zip::File.open(source, Zip::File::CREATE) do |zip|
      zip.get_output_stream("#{task.id}/000-document.pdf") { |stream| stream.write('report') }
      zip.get_output_stream("#{task.id}/001-code.py") { |stream| stream.write('code') }
    end

    individual = task.downloadable_submission_zip_path
    assert_archive_entries individual, [
      "#{task.id}/000-Design_report.pdf",
      "#{task.id}/001-source.py"
    ]

    bulk = task_definition.stub(:related_tasks_with_files, [task]) do
      unit.get_task_submissions_zip(unit.main_convenor_user, task_definition)
    end
    assert_archive_entries bulk, [
      "#{task_definition.abbreviation}-submissions/#{project.student.username}/000-Design_report.pdf",
      "#{task_definition.abbreviation}-submissions/#{project.student.username}/001-source.py"
    ]
  ensure
    FileUtils.rm_f(source) if source
    FileUtils.rm_f(individual) if individual
    FileUtils.rm_f(bulk) if bulk
  end

  private

  def assert_archive_entries(path, expected)
    Zip::File.open(path) do |zip|
      assert_equal expected.sort, zip.entries.reject(&:name_is_directory?).map(&:name).sort
    end
  end
end
