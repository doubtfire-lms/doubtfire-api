class SubmissionDownloadAuthorizationsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers
  include DownloadAuthorization

  DOWNLOAD_PATH = %r{\A/api/projects/(?<project_id>\d+)/task_def_id/(?<task_definition_id>\d+)/(?<kind>submission|submission_files)(?:\?(?<query>.*))?\z}

  def show
    return head :not_found unless trusted_caddy_request?
    return head :unauthorized unless download_header_user

    route = DOWNLOAD_PATH.match(original_uri)
    return head :not_found unless route

    download = locate_download(route)
    return head download unless download.is_a?(Hash)

    _resolved, relative_path = authorised_file_path(download[:path])
    return head :not_found unless relative_path

    serve_via_caddy(relative_path: relative_path, **download.except(:path))
  end

  private

  def locate_download(route)
    project = Project.find_by(id: route[:project_id])
    return :not_found unless project

    task_definition = project.unit.task_definitions.find_by(id: route[:task_definition_id])
    return :not_found unless task_definition
    return :forbidden unless authorise?(current_user, project, :get_submission)

    task = project.task_for_task_definition(task_definition)
    return :not_found unless task

    if route[:kind] == 'submission_files'
      submission_files_download(task, task_definition, project)
    else
      submission_pdf_download(task, task_definition, route[:query])
    end
  end

  def submission_files_download(task, task_definition, project)
    {
      path: FileHelper.zip_file_path_for_done_task(task),
      filename: FileHelper.sanitized_filename("#{project.student.username}-#{task_definition.abbreviation}.zip"),
      content_type: 'application/octet-stream',
      disposition: 'attachment'
    }
  end

  def submission_pdf_download(task, task_definition, query)
    {
      path: task.final_pdf_path,
      filename: FileHelper.sanitized_filename("#{task_definition.abbreviation}.pdf"),
      content_type: 'application/pdf',
      disposition: attachment_requested?(query) ? 'attachment' : 'inline'
    }
  end
end
