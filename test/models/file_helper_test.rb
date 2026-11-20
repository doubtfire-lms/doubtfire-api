require "test_helper"
require "open3"
require "tempfile"

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

  def test_ensure_utf8_code_does_not_execute_uploaded_filename_extension
    uploaded_filename = 'solution.rb$(touch${IFS}$CODE_UPLOAD_INJECTION_MARKER)'
    stored_filename = "000-code#{File.extname(uploaded_filename)}"
    contents = "puts 'safe'\n"

    Dir.mktmpdir do |dir|
      path = File.join(dir, stored_filename)
      marker = File.join(dir, 'injected')
      File.write(path, contents)
      previous_marker = ENV.fetch('CODE_UPLOAD_INJECTION_MARKER', nil)
      ENV['CODE_UPLOAD_INJECTION_MARKER'] = marker

      FileHelper.ensure_utf8_code(path, false)

      assert_not File.exist?(marker)
      assert_equal contents, File.read(path)
    ensure
      ENV['CODE_UPLOAD_INJECTION_MARKER'] = previous_marker
    end
  end

  def test_code_upload_rejects_shell_metacharacters_in_filename_extension
    Tempfile.create(['code', '.rb']) do |uploaded_file|
      uploaded_file.write("puts 'safe'\n")
      uploaded_file.flush

      result = FileHelper.accept_file(
        { filename: 'solution.rb$(touch${IFS}$CODE_UPLOAD_INJECTION_MARKER)', 'tempfile' => uploaded_file },
        'Code',
        'code'
      )

      assert_not result[:accepted]
      assert_equal 'invalid file extension.', result[:msg]
    end
  end

  def test_image_conversion_does_not_interpret_filename_as_shell
    Dir.mktmpdir do |dir|
      source = File.join(dir, 'upload$(touch${IFS}$IMAGE_INJECTION_MARKER).gif')
      destination = File.join(dir, 'converted.jpg')
      marker = File.join(dir, 'injected')
      FileUtils.cp(Rails.root.join('test_files/submissions/unbelievable.gif'), source)
      previous_marker = ENV.fetch('IMAGE_INJECTION_MARKER', nil)
      ENV['IMAGE_INJECTION_MARKER'] = marker

      FileHelper.compress_image_to_dest(source, destination, true)
      assert_not File.exist?(marker)
    ensure
      ENV['IMAGE_INJECTION_MARKER'] = previous_marker
    end
  end

  def test_qpdf_does_not_execute_commands_in_filename
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'submission$(touch${IFS}$QPDF_INJECTION_MARKER).pdf')
      marker = File.join(dir, 'injected')
      FileUtils.cp(Rails.root.join('test_files/submissions/valid.pdf'), path)
      previous_marker = ENV.fetch('QPDF_INJECTION_MARKER', nil)
      ENV['QPDF_INJECTION_MARKER'] = marker

      result = FileHelper.qpdf(path)
      assert_not File.exist?(marker)
      assert result
      assert File.exist?(path)
    ensure
      ENV['QPDF_INJECTION_MARKER'] = previous_marker
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
