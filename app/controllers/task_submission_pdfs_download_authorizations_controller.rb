class TaskSubmissionPdfsDownloadAuthorizationsController < NativeDownloadAuthorizationsController
  native_download :task_submission_pdfs,
                  uri: %r{\A/api/submission/unit/(?<unit_id>\d+)/task_definitions/(?<task_definition_id>\d+)/student_pdfs(?:\?.*)?\z}

  private

  def download_ids
    { unit_id: params[:id], task_definition_id: params[:task_def_id] }
  end

  def locate_download(user, unit_id:, task_definition_id:)
    unit = Unit.find_by(id: unit_id)
    return :not_found unless unit

    task_definition = unit.task_definitions.find_by(id: task_definition_id)
    return :not_found unless task_definition
    return :forbidden unless authorise?(user, unit, :get_students)

    {
      path: unit.task_submissions_pdf_zip_path(user, task_definition),
      filename: timestamped_download_name(
        unit.code, task_definition.abbreviation, user.username, 'pdfs', extension: 'zip'
      ),
      content_type: 'application/zip',
      disposition: 'attachment'
    }
  end
end
