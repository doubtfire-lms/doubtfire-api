require 'test_helper'

class DownloadAuthorizationBoundaryTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper

  CADDY_SECRET = 'download-authorization-test-secret'.freeze
  INTERNAL_REQUESTS = {
    '/api/internal/downloads/submission' => '/api/projects/1/task_def_id/1/submission',
    '/api/internal/downloads/portfolio' => '/api/submission/unit/1/portfolio',
    '/api/internal/downloads/task-submission-files' =>
      '/api/submission/unit/1/task_definitions/1/download_submissions',
    '/api/internal/downloads/task-submission-pdfs' =>
      '/api/submission/unit/1/task_definitions/1/student_pdfs',
    '/api/internal/downloads/pdf-file' => '/api/units/1/task_definitions/1/task_pdf',
    '/api/internal/downloads/unit-content' => '/api/units/1/content/sites/1/files/index.html'
  }.freeze

  def app
    Rails.application
  end

  setup do
    @original_caddy_secret = Doubtfire::Application.config.caddy_download_auth_secret
    @original_student_work_dir = Doubtfire::Application.config.student_work_dir
    @original_archive_dir = Doubtfire::Application.config.archive_dir
    @student_work_dir = Dir.mktmpdir('download-authorization-boundary')

    Doubtfire::Application.config.caddy_download_auth_secret = CADDY_SECRET
    Doubtfire::Application.config.student_work_dir = @student_work_dir
    Doubtfire::Application.config.archive_dir = File.join(@student_work_dir, 'archive')
    clear_cookies
    clear_request_headers
  end

  teardown do
    Doubtfire::Application.config.caddy_download_auth_secret = @original_caddy_secret
    Doubtfire::Application.config.student_work_dir = @original_student_work_dir
    Doubtfire::Application.config.archive_dir = @original_archive_dir
    FileUtils.rm_rf(@student_work_dir)
  end

  def test_internal_download_endpoints_reject_missing_or_incorrect_caddy_secret
    INTERNAL_REQUESTS.each do |endpoint, original_uri|
      request_internal_download(endpoint, original_uri, secret: nil)
      assert_equal 404, last_response.status, "#{endpoint} accepted a missing Caddy secret"

      request_internal_download(endpoint, original_uri, secret: 'incorrect-secret')
      assert_equal 404, last_response.status, "#{endpoint} accepted an incorrect Caddy secret"
    end
  end

  def test_blank_server_secret_disables_every_internal_download_endpoint
    Doubtfire::Application.config.caddy_download_auth_secret = nil

    INTERNAL_REQUESTS.each do |endpoint, original_uri|
      request_internal_download(endpoint, original_uri)
      assert_equal 404, last_response.status, "#{endpoint} remained enabled without a server secret"
    end
  end

  def test_trusted_internal_download_endpoints_still_require_user_authentication
    INTERNAL_REQUESTS.each do |endpoint, original_uri|
      request_internal_download(endpoint, original_uri)
      assert_equal 401, last_response.status, "#{endpoint} did not require user authentication"
    end
  end

  def test_internal_download_endpoints_reject_unrecognised_original_uris
    user = FactoryBot.create(:user)
    add_auth_header_for(user: user)

    INTERNAL_REQUESTS.each_key do |endpoint|
      header 'X-OnTrack-File', '../../etc/passwd'
      request_internal_download(endpoint, '/etc/passwd')
      assert_equal 404, last_response.status, "#{endpoint} accepted an unrecognised original URI"
      assert_nil last_response.headers['X-OnTrack-File']
    end
  end

  def test_submission_download_returns_only_an_authorised_relative_path
    unit, project, task_definition, task = create_student_task
    submission_path = task.final_pdf_path
    write_file(submission_path, '%PDF submission')

    add_auth_header_for(user: project.student)
    header 'X-OnTrack-File', '../../etc/passwd'
    request_internal_download(
      '/api/internal/downloads/submission',
      "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/submission"
    )

    assert_equal 200, last_response.status
    assert_safe_relative_file_header(submission_path)
    assert_equal 'application/pdf', last_response.headers['X-OnTrack-Content-Type']

    clear_auth_header
    add_auth_header_for(user: FactoryBot.create(:user, :student))
    request_internal_download(
      '/api/internal/downloads/submission',
      "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/submission"
    )

    assert_equal 403, last_response.status
    assert_nil last_response.headers['X-OnTrack-File']
  ensure
    unit&.destroy
  end

  def test_submission_download_rejects_a_task_definition_from_another_unit
    unit, project, = create_student_task
    other_unit = FactoryBot.create(:unit, with_students: false, task_count: 1, stream_count: 0)
    other_task_definition = other_unit.task_definitions.first
    add_auth_header_for(user: project.student)

    request_internal_download(
      '/api/internal/downloads/submission',
      "/api/projects/#{project.id}/task_def_id/#{other_task_definition.id}/submission"
    )

    assert_equal 404, last_response.status
    assert_nil last_response.headers['X-OnTrack-File']
  ensure
    unit&.destroy
    other_unit&.destroy
  end

  def test_download_rejects_a_symlink_that_escapes_student_work
    unit, project, task_definition, task = create_student_task

    Tempfile.create('outside-student-work') do |outside_file|
      outside_file.write('not student work')
      outside_file.flush
      submission_path = task.final_pdf_path
      FileUtils.mkdir_p(File.dirname(submission_path))
      FileUtils.rm_f(submission_path)
      File.symlink(outside_file.path, submission_path)

      add_auth_header_for(user: project.student)
      request_internal_download(
        '/api/internal/downloads/submission',
        "/api/projects/#{project.id}/task_def_id/#{task_definition.id}/submission"
      )

      assert_equal 404, last_response.status
      assert_nil last_response.headers['X-OnTrack-File']
    end
  ensure
    unit&.destroy
  end

  def test_pdf_download_enforces_record_scope_and_permissions
    unit = FactoryBot.create(:unit, with_students: false, task_count: 1, stream_count: 0)
    task_definition = unit.task_definitions.first
    task_sheet_path = task_definition.task_sheet(false)
    write_file(task_sheet_path, '%PDF task sheet')

    add_auth_header_for(user: unit.main_convenor_user)
    request_internal_download(
      '/api/internal/downloads/pdf-file',
      "/api/units/#{unit.id}/task_definitions/#{task_definition.id}/task_pdf"
    )

    assert_equal 200, last_response.status
    assert_safe_relative_file_header(task_sheet_path)

    clear_auth_header
    add_auth_header_for(user: FactoryBot.create(:user, :student))
    request_internal_download(
      '/api/internal/downloads/pdf-file',
      "/api/units/#{unit.id}/task_definitions/#{task_definition.id}/task_pdf"
    )

    assert_equal 403, last_response.status
    assert_nil last_response.headers['X-OnTrack-File']
  ensure
    unit&.destroy
  end

  def test_jplag_report_download_requires_permission_to_download_jplag_reports
    unit = FactoryBot.create(:unit, with_students: false, task_count: 1, stream_count: 0)
    task_definition = unit.task_definitions.first
    report_path = FileHelper.task_jplag_report_path(unit, task_definition)
    write_file(report_path, 'PK jplag report')
    report_uri = "/api/units/#{unit.id}/task_definitions/#{task_definition.id}/jplag_report"

    add_auth_header_for(user: unit.main_convenor_user)
    request_internal_download('/api/internal/downloads/pdf-file', report_uri)

    assert_equal 200, last_response.status
    assert_safe_relative_file_header(report_path)
    assert_equal 'application/octet-stream', last_response.headers['X-OnTrack-Content-Type']
    assert_includes last_response.headers['X-OnTrack-Content-Disposition'],
                    "#{unit.code}-#{task_definition.abbreviation}-jplag-report.jplag"

    clear_auth_header
    add_auth_header_for(user: FactoryBot.create(:user, :student))
    request_internal_download('/api/internal/downloads/pdf-file', report_uri)

    assert_equal 403, last_response.status
    assert_nil last_response.headers['X-OnTrack-File']
  ensure
    unit&.destroy
  end

  def test_unit_content_download_requires_content_cookie_and_confines_the_file
    unit, site = create_content_site
    content_token = unit.main_convenor_user.generate_content_authentication_token!
    set_content_credentials(unit.main_convenor_user, content_token)

    request_internal_download(
      '/api/internal/downloads/unit-content',
      "/api/units/#{unit.id}/content/sites/#{site.id}/files/index.html"
    )

    assert_equal 200, last_response.status
    assert_safe_relative_file_header(File.join(site.served_dir, 'index.html'))

    Tempfile.create('outside-unit-content') do |outside_file|
      outside_file.write('outside content')
      outside_file.flush
      served_file = File.join(site.served_dir, 'index.html')
      FileUtils.rm_f(served_file)
      File.symlink(outside_file.path, served_file)

      request_internal_download(
        '/api/internal/downloads/unit-content',
        "/api/units/#{unit.id}/content/sites/#{site.id}/files/index.html"
      )

      assert_equal 404, last_response.status
      assert_nil last_response.headers['X-OnTrack-File']
    end
  ensure
    unit&.destroy
  end

  def test_unit_content_file_paths_are_url_encoded_for_the_file_server
    unit, site = create_content_site
    content_token = unit.main_convenor_user.generate_content_authentication_token!
    set_content_credentials(unit.main_convenor_user, content_token)

    # Caddy rewrites the request to X-OnTrack-File, so an unencoded '?' would
    # truncate the path and an unencoded '%' would decode to a different file.
    {
      'query?name.txt' => 'query%3Fname.txt',
      '100%20done.txt' => '100%2520done.txt',
      'with space.txt' => 'with%20space.txt'
    }.each do |name, expected|
      write_file(File.join(site.served_dir, name), 'content')

      request_internal_download(
        '/api/internal/downloads/unit-content',
        "/api/units/#{unit.id}/content/sites/#{site.id}/files/#{ERB::Util.url_encode(name)}"
      )

      assert_equal 200, last_response.status, "#{name} was not served"
      assert_equal expected, last_response.headers['X-OnTrack-File'].split('/').last
    end
  ensure
    unit&.destroy
  end

  def test_native_download_cookies_are_scoped_to_their_own_download
    unit = FactoryBot.create(:unit, with_students: false, task_count: 1, stream_count: 0)
    user = unit.main_convenor_user
    task_definition = unit.task_definitions.first
    downloads = native_downloads(unit, task_definition, user)

    downloads.each do |download|
      write_file(download[:file_path], 'archive')
      clear_cookies
      clear_request_headers
      add_auth_header_for(user: user)
      post download[:access_path]

      assert_equal 204, last_response.status, "failed to issue #{download[:cookie_name]}"
      set_cookie = set_cookie_line(download[:cookie_name])
      assert_match(/path=#{Regexp.escape(download[:public_path])}/i, set_cookie)
      assert_match(/HttpOnly/i, set_cookie)
      assert_match(/SameSite=Strict/i, set_cookie)

      encrypted_cookie = issued_cookie_value(download[:cookie_name])
      clear_auth_header

      # Resumed downloads re-request the same URL, so reuse must work.
      2.times do |attempt|
        replay_cookie(download[:cookie_name], encrypted_cookie)
        request_internal_download(download[:internal_path], download[:public_path])

        assert_equal 200, last_response.status,
                     "use #{attempt + 1} of #{download[:cookie_name]} was rejected"
        assert_safe_relative_file_header(download[:file_path])
      end

      downloads.reject { |other| other[:cookie_name] == download[:cookie_name] }.each do |other|
        replay_cookie(download[:cookie_name], encrypted_cookie)
        request_internal_download(other[:internal_path], other[:public_path])

        assert_equal 401, last_response.status,
                     "#{download[:cookie_name]} authorised #{other[:internal_path]}"
        assert_nil last_response.headers['X-OnTrack-File']
      end
    end
  ensure
    unit&.destroy
  end

  def test_native_download_cookie_does_not_authorise_another_task_definition
    unit = FactoryBot.create(:unit, with_students: false, task_count: 2, stream_count: 0)
    user = unit.main_convenor_user
    issued_for, other = unit.task_definitions.order(:id).first(2)
    download = native_downloads(unit, issued_for, user).second
    other_download = native_downloads(unit, other, user).second
    write_file(download[:file_path], 'archive')
    write_file(other_download[:file_path], 'archive')

    add_auth_header_for(user: user)
    post download[:access_path]
    encrypted_cookie = issued_cookie_value(download[:cookie_name])
    clear_auth_header

    replay_cookie(download[:cookie_name], encrypted_cookie)
    request_internal_download(other_download[:internal_path], other_download[:public_path])

    assert_equal 401, last_response.status
    assert_nil last_response.headers['X-OnTrack-File']
  ensure
    unit&.destroy
  end

  def test_direct_rails_downloads_name_the_file_in_content_disposition
    unit = FactoryBot.create(:unit, with_students: false, task_count: 1, stream_count: 0)
    user = unit.main_convenor_user
    task_definition = unit.task_definitions.first

    native_downloads(unit, task_definition, user).each do |download|
      write_file(download[:file_path], 'archive')
      clear_cookies
      clear_request_headers
      add_auth_header_for(user: user)
      post download[:access_path]

      encrypted_cookie = issued_cookie_value(download[:cookie_name])
      clear_auth_header
      replay_cookie(download[:cookie_name], encrypted_cookie)
      get download[:public_path]

      assert_equal 200, last_response.status, "#{download[:public_path]} was not served"

      # Without this the browser falls back to naming the file after the last
      # URL segment, e.g. "portfolio" with no extension.
      disposition = last_response.headers['Content-Disposition']
      assert_match(/\Aattachment;/, disposition)
      assert_match(/filename="[^"]+\.zip"/, disposition)
      assert_equal 'application/zip', last_response.headers['Content-Type']
      assert_equal 'rails', last_response.headers['X-OnTrack-Served-By']
    end
  ensure
    unit&.destroy
  end

  def test_expired_native_download_cookie_is_rejected_without_serving_a_file
    unit = FactoryBot.create(:unit, with_students: false, task_count: 1, stream_count: 0)
    user = unit.main_convenor_user
    task_definition = unit.task_definitions.first
    download = native_downloads(unit, task_definition, user).first
    write_file(download[:file_path], 'archive')

    add_auth_header_for(user: user)
    post download[:access_path]
    encrypted_cookie = issued_cookie_value(download[:cookie_name])
    clear_auth_header

    travel 31.seconds do
      replay_cookie(download[:cookie_name], encrypted_cookie)
      request_internal_download(download[:internal_path], download[:public_path])

      assert_equal 401, last_response.status
      assert_nil last_response.headers['X-OnTrack-File']
    end
  ensure
    unit&.destroy
  end

  private

  def request_internal_download(endpoint, original_uri, secret: CADDY_SECRET)
    header 'X-OnTrack-Download-Auth', secret
    header 'X-Forwarded-Uri', original_uri
    get endpoint
  end

  def clear_request_headers
    clear_auth_header
    header 'Cookie', nil
    header 'X-OnTrack-Download-Auth', nil
    header 'X-Forwarded-Uri', nil
  end

  def create_student_task
    unit = FactoryBot.create(:unit, with_students: false, task_count: 1, stream_count: 0)
    student = FactoryBot.create(:user, :student)
    project = unit.enrol_student(student, nil)
    task_definition = unit.task_definitions.first
    task = project.task_for_task_definition(task_definition)
    [unit, project, task_definition, task]
  end

  def create_content_site
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, stream_count: 0)
    archive = Tempfile.new(['download-authorization-content', '.zip'])
    Zip::File.open(archive.path, Zip::File::CREATE) do |zip|
      zip.get_output_stream('index.html') { |stream| stream.write('<h1>Content</h1>') }
    end
    site = UnitContentSite.store_upload!(
      unit,
      { filename: 'content.zip', tempfile: archive }
    )
    archive.close
    [unit, site]
  end

  def set_content_credentials(user, token)
    set_cookie "username=#{Rack::Utils.escape(user.username)}"
    set_cookie "#{AuthenticationHelpers::CONTENT_TOKEN_COOKIE}=#{Rack::Utils.escape(token.authentication_token)}"
  end

  def native_downloads(unit, task_definition, user)
    [
      {
        access_path: "/api/submission/unit/#{unit.id}/portfolio/access",
        public_path: "/api/submission/unit/#{unit.id}/portfolio",
        internal_path: '/api/internal/downloads/portfolio',
        cookie_name: NativeDownloadCookie.cookie_name(:portfolio),
        file_path: unit.get_portfolio_zip_filename(user)
      },
      {
        access_path: "/api/submission/unit/#{unit.id}/task_definitions/#{task_definition.id}/download_submissions/access",
        public_path: "/api/submission/unit/#{unit.id}/task_definitions/#{task_definition.id}/download_submissions",
        internal_path: '/api/internal/downloads/task-submission-files',
        cookie_name: NativeDownloadCookie.cookie_name(:task_submission_files),
        file_path: unit.task_submissions_zip_path(user, task_definition)
      },
      {
        access_path: "/api/submission/unit/#{unit.id}/task_definitions/#{task_definition.id}/student_pdfs/access",
        public_path: "/api/submission/unit/#{unit.id}/task_definitions/#{task_definition.id}/student_pdfs",
        internal_path: '/api/internal/downloads/task-submission-pdfs',
        cookie_name: NativeDownloadCookie.cookie_name(:task_submission_pdfs),
        file_path: unit.task_submissions_pdf_zip_path(user, task_definition)
      }
    ]
  end

  def replay_cookie(name, value)
    # `value` is already in Set-Cookie wire form, so replay it verbatim.
    header 'Cookie', "#{name}=#{value}"
  end

  def set_cookie_line(name)
    Array(last_response.headers['Set-Cookie']).join("\n").lines.map(&:strip)
                                              .find { |line| line.start_with?("#{name}=") }
  end

  # CGI::Cookie#value is array-like and holds the percent-encoded wire value,
  # which is what the browser sends back. Rack::Test's own accessors drop the
  # cookie's flags, so attribute assertions read the raw header instead.
  def issued_cookie_value(name)
    last_response.cookies.fetch(name).value.first.to_s
  end

  def write_file(path, contents)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, contents)
  end

  def assert_safe_relative_file_header(expected_path)
    relative_path = last_response.headers['X-OnTrack-File']
    expected = Pathname.new(expected_path).realpath.relative_path_from(Pathname.new(@student_work_dir).realpath).to_s
    assert_equal expected.split('/').map { |segment| ERB::Util.url_encode(segment) }.join('/'), relative_path
    assert_not Pathname.new(relative_path).absolute?
    assert_not_includes Pathname.new(relative_path).each_filename.to_a, '..'
  end
end
