require "test_helper"
require "open3"
require "zip"

class FileHelperTest < ActiveSupport::TestCase
  def with_word_document_conversion_configured
    config = Doubtfire::Application.config
    original_image = config.gotenberg_image
    original_mount = config.gotenberg_workdir_volume_mount
    original_fallback = config.gotenberg_fallback_volume_container
    config.gotenberg_image = 'doubtfire-gotenberg:test'
    config.gotenberg_workdir_volume_mount = nil
    config.gotenberg_fallback_volume_container = 'fallback-container'
    yield
  ensure
    config.gotenberg_image = original_image
    config.gotenberg_workdir_volume_mount = original_mount
    config.gotenberg_fallback_volume_container = original_fallback
  end

  def test_convert_use_with_gif
    in_file = "#{Rails.root}/test_files/submissions/unbelievable.gif"

    Dir.mktmpdir do |dir|
      dest_file = "#{dir}#{File.basename(in_file, ".*")}.jpg"
      assert FileHelper.compress_image_to_dest(in_file, dest_file, true)
      assert File.exist? dest_file
    end
  end

  def test_accepts_docx_as_a_task_document
    with_word_document_conversion_configured do
      Tempfile.create(['submission', '.docx']) do |docx_file|
        FileUtils.cp(Rails.root.join('test_files/TestWordDoc.docx'), docx_file.path)

        result = FileHelper.accept_file(
          {
            filename: 'submission.docx',
            'tempfile' => docx_file
          },
          'Report',
          'document',
          allow_word_documents: true
        )

        assert result[:accepted], result[:msg]
      end
    end
  end

  def test_rejects_docx_when_word_document_conversion_is_not_configured
    config = Doubtfire::Application.config
    original_image = config.gotenberg_image
    original_mount = config.gotenberg_workdir_volume_mount
    original_fallback = config.gotenberg_fallback_volume_container
    config.gotenberg_image = nil
    config.gotenberg_workdir_volume_mount = nil
    config.gotenberg_fallback_volume_container = nil

    File.open(Rails.root.join('test_files/TestWordDoc.docx')) do |docx_file|
      result = FileHelper.accept_file(
        {
          filename: 'submission.docx',
          'tempfile' => docx_file
        },
        'Report',
        'document',
        allow_word_documents: true
      )

      assert_not result[:accepted]
      assert_equal(
        'Word documents are currently not supported.',
        result[:msg]
      )
    end
  ensure
    config.gotenberg_image = original_image
    config.gotenberg_workdir_volume_mount = original_mount
    config.gotenberg_fallback_volume_container = original_fallback
  end

  def test_rejects_docx_where_word_documents_are_not_enabled
    Tempfile.create(['submission', '.docx']) do |docx_file|
      FileUtils.cp(Rails.root.join('test_files/TestWordDoc.docx'), docx_file.path)

      result = FileHelper.accept_file(
        {
          filename: 'submission.docx',
          'tempfile' => docx_file
        },
        'Report',
        'document'
      )

      assert_not result[:accepted]
    end
  end

  def test_rejects_encrypted_docx_with_an_explicit_error
    with_word_document_conversion_configured do
      File.open(Rails.root.join('test_files/submissions/encrypted.docx')) do |docx_file|
        result = FileHelper.accept_file(
          {
            filename: 'submission.docx',
            'tempfile' => docx_file
          },
          'Submission',
          'document',
          allow_word_documents: true
        )

        assert_not result[:accepted]
        assert_equal(
          'Word document is encrypted or password protected. Remove the password protection and upload it again.',
          result[:msg]
        )
      end
    end
  end

  def test_word_document_conversion_requires_an_image_and_work_directory_source
    config = Doubtfire::Application.config
    original_image = config.gotenberg_image
    original_mount = config.gotenberg_workdir_volume_mount
    original_fallback = config.gotenberg_fallback_volume_container

    config.gotenberg_image = nil
    config.gotenberg_workdir_volume_mount = '/host/gotenberg'
    assert_not FileHelper.word_document_conversion_configured?

    config.gotenberg_image = 'doubtfire-gotenberg:test'
    config.gotenberg_workdir_volume_mount = nil
    config.gotenberg_fallback_volume_container = nil
    assert_not FileHelper.word_document_conversion_configured?

    config.gotenberg_workdir_volume_mount = '/host/gotenberg'
    assert FileHelper.word_document_conversion_configured?

    config.gotenberg_workdir_volume_mount = nil
    config.gotenberg_fallback_volume_container = 'fallback-container'
    assert FileHelper.word_document_conversion_configured?
  ensure
    config.gotenberg_image = original_image
    config.gotenberg_workdir_volume_mount = original_mount
    config.gotenberg_fallback_volume_container = original_fallback
  end

  def test_converts_docx_to_pdf_with_gotenberg
    successful_status = Struct.new(:exitstatus) do
      def success?
        true
      end
    end.new(0)
    runner = lambda do |work_id|
      FileUtils.cp(
        Rails.root.join('test_files/submissions/valid.pdf'),
        Rails.root.join('tmp/gotenberg', work_id, 'output.pdf')
      )
      ['', '', successful_status]
    end

    Dir.mktmpdir do |dir|
      source_path = File.join(dir, 'submission.docx')
      destination_path = File.join(dir, 'submission.pdf')
      FileUtils.cp(Rails.root.join('test_files/TestWordDoc.docx'), source_path)

      original_runner = FileHelper.method(:run_word_document_conversion)
      FileHelper.define_singleton_method(:run_word_document_conversion, runner)
      begin
        result = FileHelper.convert_word_document_to_pdf(
          source_path,
          destination_path,
          work_id: 'test-work-id'
        )
      ensure
        FileHelper.define_singleton_method(:run_word_document_conversion, original_runner)
      end

      assert_equal destination_path, result
      assert FileHelper.validate_pdf(destination_path)[:valid]
    end
  end

  def test_gotenberg_uses_an_isolated_host_work_directory_mount_when_configured
    config = Doubtfire::Application.config
    original_mount = config.gotenberg_workdir_volume_mount
    original_fallback = config.gotenberg_fallback_volume_container
    config.gotenberg_workdir_volume_mount = '/host/gotenberg'
    config.gotenberg_fallback_volume_container = 'fallback-container'

    assert_equal(
      ['--volume', '/host/gotenberg/test-work-id:/workdir/gotenberg/test-work-id'],
      FileHelper.gotenberg_volume_arguments('test-work-id')
    )
  ensure
    config.gotenberg_workdir_volume_mount = original_mount
    config.gotenberg_fallback_volume_container = original_fallback
  end

  def test_gotenberg_uses_the_development_volume_container_fallback
    config = Doubtfire::Application.config
    original_mount = config.gotenberg_workdir_volume_mount
    original_fallback = config.gotenberg_fallback_volume_container
    config.gotenberg_workdir_volume_mount = nil
    config.gotenberg_fallback_volume_container = 'fallback-container'

    assert_equal(
      ['--volumes-from', 'fallback-container'],
      FileHelper.gotenberg_volume_arguments('test-work-id')
    )
  ensure
    config.gotenberg_workdir_volume_mount = original_mount
    config.gotenberg_fallback_volume_container = original_fallback
  end

  def test_gotenberg_worker_runs_in_its_own_network_namespace
    config = Doubtfire::Application.config
    original_image = config.gotenberg_image
    original_mount = config.gotenberg_workdir_volume_mount
    config.gotenberg_image = 'doubtfire-gotenberg:test'
    config.gotenberg_workdir_volume_mount = '/host/gotenberg'

    command = FileHelper.word_document_conversion_command('test-work-id')
    network_index = command.index('--network')

    assert_equal 'none', command[network_index + 1]
    assert_not(command.any? { |argument| argument.start_with?('container:') })
    assert_equal 'doubtfire-gotenberg:test', command[-2]
  ensure
    config.gotenberg_image = original_image
    config.gotenberg_workdir_volume_mount = original_mount
  end

  def test_archive_paths
    unit = FactoryBot.create(:unit, with_students: false)

    archive_work_path = FileHelper.unit_work_root(unit, archived: :force)
    original_work_path = FileHelper.unit_work_root(unit, archived: false)

    archive_portfolio_path = FileHelper.unit_portfolio_dir(unit, create: false, archived: :force)
    original_portfolio_path = FileHelper.unit_portfolio_dir(unit, create: false, archived: false)

    archive_jplag_path = FileHelper.unit_jplag_report_dir(unit, archived: :force)
    original_jplag_path = FileHelper.unit_jplag_report_dir(unit, archived: false)

    assert_match %r{^#{FileHelper.archive_root}/}, archive_work_path
    assert_match %r{^#{FileHelper.archive_root}/portfolio/}, archive_portfolio_path
    assert_match %r{^#{FileHelper.archive_root}/jplag/results/}, archive_jplag_path
    assert_match %r{^#{FileHelper.student_work_root}/}, original_work_path
    assert_match %r{^#{FileHelper.student_work_root}/portfolio/}, original_portfolio_path
    assert_match %r{^#{FileHelper.student_work_root}/jplag/results/}, original_jplag_path
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

  def test_zip_upload_rejects_nested_archives
    Tempfile.create(['submission', '.zip']) do |zip_file|
      Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
        zip.get_output_stream('lib/vendor.zip') { |io| io.write('nested archive') }
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
      assert_includes result[:msg], 'Nested archives are not allowed'
    end
  end

  def test_zip_upload_accepts_entries_larger_than_file_limit
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

      assert result[:accepted], result[:msg]
    end
  ensure
    Doubtfire::Application.config.max_file_size = original_max_file_size
  end

  def test_zip_upload_rejects_total_uncompressed_size_over_multiplier_limit
    original_max_file_size = Doubtfire::Application.config.max_file_size
    original_multiplier = Doubtfire::Application.config.zip_uncompressed_size_multiplier
    Doubtfire::Application.config.max_file_size = 1_000
    Doubtfire::Application.config.zip_uncompressed_size_multiplier = 2

    Tempfile.create(['submission', '.zip']) do |zip_file|
      Zip::File.open(zip_file.path, Zip::File::CREATE) do |zip|
        3.times do |index|
          zip.get_output_stream("file-#{index}.txt") { |io| io.write('a' * 900) }
        end
      end

      result = FileHelper.validate_zip_upload(zip_file.path, 'submission.zip')

      refute result[:valid]
      assert_includes result[:msg], 'uncompressed size limit'
    end
  ensure
    Doubtfire::Application.config.max_file_size = original_max_file_size
    Doubtfire::Application.config.zip_uncompressed_size_multiplier = original_multiplier
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
