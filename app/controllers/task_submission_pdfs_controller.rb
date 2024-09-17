require 'grape'

class TaskSubmissionPdfsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers
  include LogHelper

  class MyException < RuntimeError
    attr_reader :status

    def initialize(status)
      @status = status
    end
  end

  def error!(message, status = options[:default_status], _headers = {}, _backtrace = [])
    raise MyException.new(status), message
  end

  # desc "Retrieve student PDFs for a unit"
  def index
    unless authenticated?
      error!({ error: "Not authorised to download student PDFs for unit '#{params[:id]}'" }, 401)
    end

    unit = Unit.find(params[:id])

    unless authorise? current_user, unit, :get_students
      error!({ error: "Not authorised to download student PDFs for unit '#{params[:id]}'" }, 401)
    end

    td = unit.task_definitions.find(params[:task_def_id])

    output_zip = unit.get_task_submissions_pdf_zip(current_user, td)

    error!({ error: 'No files to download' }, 403) if output_zip.nil?

    # Set download headers...
    # content_type "application/octet-stream"
    download_id = "#{Time.zone.now.strftime('%Y-%m-%d %H:%m:%S')}-#{unit.code}-#{td.abbreviation}-#{current_user.username}-pdfs"
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
