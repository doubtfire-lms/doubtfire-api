require "test_helper"
require "open3"

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

  def test_process_audio_converts_webm_audio
    source_wav = "/workspace/doubtfire-web/src/assets/sounds/discussion-start-signal.wav"

    Dir.mktmpdir("audio path ") do |dir|
      webm_input = File.join(dir, "browser recording.webm")
      wav_output = File.join(dir, "processed recording.wav")

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
