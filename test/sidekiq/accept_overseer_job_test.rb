require 'test_helper'

class AcceptOverseerJobTest < ActiveSupport::TestCase
  def test_assessment_archive_cannot_escape_the_work_directory
    Dir.mktmpdir('overseer-resources') do |root|
      work_dir = File.join(root, 'work')
      archive_path = File.join(root, 'assessment.zip')
      escaped_path = File.join(root, 'escaped.txt')
      FileUtils.mkdir_p(work_dir)

      write_zip(archive_path,
                'nested/resource.txt' => 'ordinary resource',
                '../escaped.txt' => 'outside the work directory')

      assert_raises(Zip::Error) do
        AcceptOverseerJob.new.extract_overseer_resource_files(archive_path, work_dir)
      end
      assert_not File.exist?(escaped_path)
      assert_not File.exist?(File.join(work_dir, 'nested/resource.txt'))
    end
  end

  def test_assessment_archive_rejects_symlinks
    Dir.mktmpdir('overseer-resources') do |root|
      work_dir = File.join(root, 'work')
      archive_path = File.join(root, 'assessment.zip')
      link_path = File.join(root, 'link')
      FileUtils.mkdir_p(work_dir)
      File.symlink(root, link_path)

      Zip::File.open(archive_path, Zip::File::CREATE) do |zip|
        zip.add('link', link_path)
      end

      assert_raises(Zip::Error) do
        AcceptOverseerJob.new.extract_overseer_resource_files(archive_path, work_dir)
      end
      assert_not File.exist?(File.join(work_dir, 'link'))
    end
  end

  def test_assessment_archive_cannot_follow_an_existing_symlink
    Dir.mktmpdir('overseer-resources') do |root|
      work_dir = File.join(root, 'work')
      archive_path = File.join(root, 'assessment.zip')
      escaped_path = File.join(root, 'escaped.txt')
      FileUtils.mkdir_p(work_dir)
      File.symlink(root, File.join(work_dir, 'link'))

      write_zip(archive_path, 'link/escaped.txt' => 'outside the work directory')

      assert_raises(Zip::Error) do
        AcceptOverseerJob.new.extract_overseer_resource_files(archive_path, work_dir)
      end
      assert_not File.exist?(escaped_path)
    end
  end

  def test_assessment_archive_extracts_nested_resources
    Dir.mktmpdir('overseer-resources') do |root|
      work_dir = File.join(root, 'work')
      archive_path = File.join(root, 'assessment.zip')
      FileUtils.mkdir_p(work_dir)

      write_zip(archive_path, 'nested/resource.txt' => 'ordinary resource')

      AcceptOverseerJob.new.extract_overseer_resource_files(archive_path, work_dir)

      assert_equal 'ordinary resource', File.read(File.join(work_dir, 'nested/resource.txt'))
    end
  end

  private

  def write_zip(path, entries)
    Zip::File.open(path, Zip::File::CREATE) do |zip|
      entries.each do |entry_name, contents|
        zip.get_output_stream(entry_name) { |stream| stream.write(contents) }
      end
    end
  end
end
