require 'grape'

class TaskDownloadsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers
  include LogHelper
  include TaskSubmissionFilesDownloadAuthentication

  class MyException < RuntimeError
    attr_reader :status

    def initialize(status)
      @status = status
    end
  end

  def error!(message, status = options[:default_status], _headers = {}, _backtrace = [])
    raise MyException.new(status), message
  end

  # desc "Retrieve tasks for a unit"
  def index
    download_user = authenticated_task_submission_files_download_user(
      unit_id: params[:id],
      task_definition_id: params[:task_def_id]
    )

    unless download_user
      error!({ error: "Not authorised to download tasks for unit '#{params[:id]}'" }, 401)
    end

    unit = Unit.find(params[:id])

    unless authorise? download_user, unit, :get_students
      error!({ error: "Not authorised to download tasks for unit '#{params[:id]}'" }, 401)
    end

    td = unit.task_definitions.find(params[:task_def_id])

    output_zip = unit.get_task_submissions_zip(download_user, td)

    error!({ error: 'No files to download' }, 403) if output_zip.nil?

    # Set download headers...
    # content_type "application/octet-stream"
    download_id = "#{Time.zone.now.strftime('%Y-%m-%d %H:%m:%S')}-#{unit.code}-#{td.abbreviation}-#{download_user.username}-files"
    download_id.gsub! /[\\\/]/, '-'
    download_id = FileHelper.sanitized_filename(download_id)
    # header['Content-Disposition'] = "attachment; filename=#{download_id}.zip"
    # env['api.format'] = :binary

    logger.debug "Downloading task for #{td.abbreviation} from #{output_zip}"

    send_file output_zip, content_type: 'application/octet-stream', disposition: "attachment; filename=#{download_id}.zip"
  rescue MyException => e
    render json: e.message, status: e.status
  end
end
