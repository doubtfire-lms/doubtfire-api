require 'test_helper'
require 'tmpdir'
require 'zip'

class SubmissionHistoryTest < ActiveSupport::TestCase
  def test_creates_archive_with_only_selected_upload_requirements
    unit = FactoryBot.create(:unit, task_count: 1)
    task = unit.active_projects.first.task_for_task_definition(unit.task_definitions.first)
    task.task_definition.update!(
      assessment_enabled: false,
      upload_requirements: [
        { 'key' => 'file0', 'name' => 'main.rb', 'type' => 'code', 'submission_history' => true },
        { 'key' => 'file1', 'name' => 'report.pdf', 'type' => 'document', 'submission_history' => false }
      ]
    )

    Dir.mktmpdir do |dir|
      source_path = File.join(dir, 'done.zip')
      output_path = File.join(dir, 'history')
      create_source_archive(source_path, task.id)

      FileHelper.stub(:zip_file_path_for_done_task, source_path) do
        FileHelper.stub(:task_submission_identifier_path_with_timestamp, output_path) do
          history = SubmissionHistory.create_archive!(task, '12345')

          assert history.persisted?
          Zip::File.open(history.submission_zip_file_name) do |zip|
            assert zip.find_entry("#{task.id}/000-code.rb")
            assert_nil zip.find_entry("#{task.id}/001-document.pdf")
          end
        end
      end
    end
  end

  def test_does_not_create_record_when_archive_copy_fails
    unit = FactoryBot.create(:unit, task_count: 1)
    task = unit.active_projects.first.task_for_task_definition(unit.task_definitions.first)
    task.task_definition.update!(
      assessment_enabled: false,
      upload_requirements: [
        { 'key' => 'file0', 'name' => 'main.rb', 'type' => 'code', 'submission_history' => true }
      ]
    )

    assert_no_difference('SubmissionHistory.count') do
      assert_raises(RuntimeError) do
        FileHelper.stub(:zip_file_path_for_done_task, '/missing/submission.zip') do
          SubmissionHistory.create_archive!(task, '12345')
        end
      end
    end
  end

  private

  def create_source_archive(path, task_id)
    Zip::File.open(path, create: true) do |zip|
      zip.get_output_stream("#{task_id}/000-code.rb") { |file| file.write('puts "hello"') }
      zip.get_output_stream("#{task_id}/001-document.pdf") { |file| file.write('%PDF') }
    end
  end
end
