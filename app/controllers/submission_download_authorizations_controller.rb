require 'pathname'

class SubmissionDownloadAuthorizationsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers

  DOWNLOAD_PATH = %r{\A/api/projects/(?<project_id>\d+)/task_def_id/(?<task_definition_id>\d+)/(?<kind>submission|submission_files)(?:\?(?<query>.*))?\z}
  INTERNAL_SECRET_HEADER = 'X-OnTrack-Download-Auth'.freeze
  ORIGINAL_URI_HEADER = 'X-Forwarded-Uri'.freeze

  def show
    return head :not_found unless trusted_caddy_request?
    return head :unauthorized unless authenticated_for_download?

    route_params = DOWNLOAD_PATH.match(request.headers[ORIGINAL_URI_HEADER].to_s)
    return head :not_found unless route_params

    project = Project.find_by(id: route_params[:project_id])
    return head :not_found unless project

    task_definition = project.unit.task_definitions.find_by(id: route_params[:task_definition_id])
    return head :not_found unless task_definition
    return head :forbidden unless authorise?(current_user, project, :get_submission)

    task = project.task_for_task_definition(task_definition)
    return head :not_found unless task

    file_path, filename, content_type, disposition_type = download_metadata(task, task_definition, project, route_params)
    resolved_path, relative_path = authorised_file_path(file_path)
    return head :not_found unless resolved_path

    disposition = ActionDispatch::Http::ContentDisposition.format(disposition: disposition_type, filename: filename)

    response.set_header('X-OnTrack-File', relative_path)
    response.set_header('X-OnTrack-Content-Disposition', disposition)
    response.set_header('X-OnTrack-Content-Type', content_type)

    head :ok
  end

  private

  def trusted_caddy_request?
    expected = ENV.fetch('DF_CADDY_DOWNLOAD_AUTH_SECRET', '')
    provided = request.headers[INTERNAL_SECRET_HEADER].to_s
    return false if expected.blank? || provided.blank?

    ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def authenticated_for_download?
    username, token = get_user_and_token_from(:header)
    user_auth_token_type(username, token, :general) == :valid
  end

  def download_metadata(task, task_definition, project, route_params)
    if route_params[:kind] == 'submission_files'
      filename = FileHelper.sanitized_filename("#{project.student.username}-#{task_definition.abbreviation}.zip")
      [FileHelper.zip_file_path_for_done_task(task), filename, 'application/octet-stream', 'attachment']
    else
      filename = FileHelper.sanitized_filename("#{task_definition.abbreviation}.pdf")
      disposition = attachment_requested?(route_params[:query]) ? 'attachment' : 'inline'
      [task.final_pdf_path, filename, 'application/pdf', disposition]
    end
  end

  def attachment_requested?(query)
    ActiveModel::Type::Boolean.new.cast(Rack::Utils.parse_nested_query(query.to_s)['as_attachment'])
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
