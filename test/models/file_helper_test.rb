require "test_helper"
require "open3"
require "zip"

class FileHelperTest < ActiveSupport::TestCase
  def test_convert_use_with_gif
    in_file = "#{Rails.root}/test_files/submissions/unbelievable.gif"

    Dir.mktmpdir do |dir|
      dest_file = "#{dir}#{File.basename(in_file, ".*")}.jpg"
      assert FileHelper.compress_image_to_dest(in_file, dest_file, true)
      assert File.exist? dest_file
    end
  end

  def test_archive_paths
    unit = FactoryBot.create(:unit, with_students: false)

    archive_work_path = FileHelper.unit_work_root(unit, archived: :force)
    original_work_path = FileHelper.unit_work_root(unit, archived: false)

    archive_portfolio_path = FileHelper.unit_portfolio_dir(unit, create: false, archived: :force)
    original_portfolio_path = FileHelper.unit_portfolio_dir(unit, create: false, archived: false)

    assert_match %r{^#{FileHelper.archive_root}/}, archive_work_path
    assert_match %r{^#{FileHelper.archive_root}/portfolio/}, archive_portfolio_path
    assert_match %r{^#{FileHelper.student_work_root}/}, original_work_path
    assert_match %r{^#{FileHelper.student_work_root}/portfolio/}, original_portfolio_path
  end

  def test_accept_zip_upload
    Tempfile.create(['submission', '.zip']) do |zip_file|
      Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
        zip.get_output_stream('src/main.rb') { |io| io.write("puts 'hello'\n") }
      end

      result = FileHelper.accept_file(
        {
          filename: 'submission.zip',
          'tempfile' => zip_file
        },
        'Zip',
        'zip'
      )

      assert result[:accepted], result[:msg]
    end
  end

  def test_zip_upload_rejects_unsafe_paths
    Tempfile.create(['submission', '.zip']) do |zip_file|
      Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
        zip.get_output_stream('../escape.rb') { |io| io.write("puts 'bad'\n") }
      end

      result = FileHelper.accept_file(
        {
          filename: 'submission.zip',
          'tempfile' => zip_file
        },
        'Zip',
        'zip'
      )

      refute result[:accepted]
      assert_includes result[:msg], 'unsafe path'
    end
  end

  def test_zip_upload_rejects_entries_larger_than_file_limit
    original_max_file_size = Doubtfire::Application.config.max_file_size
    Doubtfire::Application.config.max_file_size = 1_000

    Tempfile.create(['submission', '.zip']) do |zip_file|
      Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
        zip.get_output_stream('large.txt') { |io| io.write('a' * 1_001) }
      end

      result = FileHelper.accept_file(
        {
          filename: 'submission.zip',
          'tempfile' => zip_file
        },
        'Zip',
        'zip'
      )

      refute result[:accepted]
      assert_includes result[:msg], 'larger than'
    end
  ensure
    Doubtfire::Application.config.max_file_size = original_max_file_size
  end

  def test_zip_file_tree_lists_nested_paths
    Tempfile.create(['submission', '.zip']) do |zip_file|
      Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
        zip.get_output_stream('src/main.rb') { |io| io.write("puts 'hello'\n") }
        zip.get_output_stream('README.md') { |io| io.write("# Read me\n") }
      end

      tree = FileHelper.zip_file_tree(zip_file.path, 'submission.zip')

      assert_equal 2, tree[:entries]
      assert_includes tree[:lines], '↳ src/'
      assert_includes tree[:lines], '  ↳ main.rb'
      assert_includes tree[:lines], '↳ README.md'
      refute tree[:truncated]
    end
  end

  def test_process_audio_converts_webm_audio
    Dir.mktmpdir("audio path ") do |dir|
      source_wav = File.join(dir, "source tone.wav")
      webm_input = File.join(dir, "browser recording.webm")
      wav_output = File.join(dir, "processed recording.wav")

      source_success = system(
        Doubtfire::Application.config.institution[:ffmpeg],
        "-loglevel", "quiet",
        "-y",
        "-f", "lavfi",
        "-i", "sine=frequency=440:duration=1",
        source_wav
      )
      assert source_success, "Expected ffmpeg to create a WAV fixture for the test"

      success = system(
        Doubtfire::Application.config.institution[:ffmpeg],
        "-loglevel", "quiet",
        "-y",
        "-i", source_wav,
        "-c:a", "libopus",
        webm_input
      )
      assert success, "Expected ffmpeg to create a WebM fixture for the test"

      assert FileHelper.process_audio(webm_input, wav_output)
      assert File.exist?(wav_output)
      assert_operator File.size(wav_output), :>, 0
    end
  end
end
