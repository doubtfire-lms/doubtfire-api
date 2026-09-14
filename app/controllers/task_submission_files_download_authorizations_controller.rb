require 'pathname'

class TaskSubmissionFilesDownloadAuthorizationsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers
  include TaskSubmissionFilesDownloadAuthentication

  skip_forgery_protection only: :create

  DOWNLOAD_PATH = %r{\A/api/submission/unit/(?<unit_id>\d+)/task_definitions/(?<task_definition_id>\d+)/download_submissions(?:\?.*)?\z}
  INTERNAL_SECRET_HEADER = 'X-OnTrack-Download-Auth'.freeze
  ORIGINAL_URI_HEADER = 'X-Forwarded-Uri'.freeze

  def show
    return head :not_found unless trusted_caddy_request?

    route_params = DOWNLOAD_PATH.match(request.headers[ORIGINAL_URI_HEADER].to_s)
    return head :not_found unless route_params

    @download_user = authenticated_task_submission_files_download_user(
      unit_id: route_params[:unit_id],
      task_definition_id: route_params[:task_definition_id]
    )
    return head :unauthorized unless @download_user

    unit, task_definition = find_download_records(route_params[:unit_id], route_params[:task_definition_id])
    return head :not_found unless unit && task_definition
    return head :forbidden unless authorise?(@download_user, unit, :get_students)

    _resolved_path, relative_path = authorised_file_path(
      unit.task_submissions_zip_path(@download_user, task_definition)
    )
    return head :not_found unless relative_path

    disposition = ActionDispatch::Http::ContentDisposition.format(
      disposition: 'attachment',
      filename: download_filename(unit, task_definition, @download_user)
    )

    response.set_header('X-OnTrack-File', relative_path)
    response.set_header('X-OnTrack-Content-Disposition', disposition)
    response.set_header('X-OnTrack-Content-Type', 'application/zip')
    head :ok
  end

  def create
    @download_user = authenticated_task_submission_files_header_user
    return head :unauthorized unless @download_user

    unit, task_definition = find_download_records(params[:id], params[:task_def_id])
    return head :not_found unless unit && task_definition
    return head :forbidden unless authorise?(@download_user, unit, :get_students)
    return head :not_found unless authorised_file_path(
      unit.task_submissions_zip_path(@download_user, task_definition)
    ).first

    expires_at = Time.current + TASK_SUBMISSION_FILES_DOWNLOAD_COOKIE_LIFETIME
    cookies.encrypted[TASK_SUBMISSION_FILES_DOWNLOAD_COOKIE] = {
      value: {
        user_id: @download_user.id,
        unit_id: unit.id,
        task_definition_id: task_definition.id,
        expires_at: expires_at.to_i
      }.to_json,
      expires: expires_at,
      domain: Doubtfire::Application.config.institution[:cookie_domain],
      path: download_url_path(unit, task_definition),
      secure: request.ssl? || Rails.env.production?,
      httponly: true,
      same_site: :strict
    }

    head :no_content
  end

  private

  def trusted_caddy_request?
    expected = Doubtfire::Application.config.caddy_download_auth_secret.to_s
    provided = request.headers[INTERNAL_SECRET_HEADER].to_s
    return false if expected.blank? || provided.blank?

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def find_download_records(unit_id, task_definition_id)
    unit = Unit.find_by(id: unit_id)
    return [nil, nil] unless unit

    [unit, unit.task_definitions.find_by(id: task_definition_id)]
  end

  def download_url_path(unit, task_definition)
    "/api/submission/unit/#{unit.id}/task_definitions/#{task_definition.id}/download_submissions"
  end

  def download_filename(unit, task_definition, user)
    download_id = "#{Time.zone.now.strftime('%Y-%m-%d %H:%m:%S')}-#{unit.code}-#{task_definition.abbreviation}-#{user.username}-files"
    "#{FileHelper.sanitized_filename(download_id.tr('\\/', '-'))}.zip"
  end

  def authorised_file_path(file_path)
    return [nil, nil] if file_path.blank? || !File.file?(file_path)

    root = Pathname.new(Doubtfire::Application.config.student_work_dir).realpath
    resolved = Pathname.new(file_path).realpath
    root_prefix = "#{root}#{File::SEPARATOR}"
    return [nil, nil] unless resolved.to_s.start_with?(root_prefix)

    [resolved, resolved.relative_path_from(root).to_s]
  rescue Errno::ENOENT, Errno::EACCES
    [nil, nil]
  end
end
