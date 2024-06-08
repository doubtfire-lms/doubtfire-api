require 'grape'

class LectureResourceDownloadsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers

  class MyException < RuntimeError
    attr_reader :status

    def initialize(status)
      @status = status
    end
  end

  def error!(message, status = options[:default_status], _headers = {}, _backtrace = [])
    raise MyException.new(status), message
  end

  # desc "Retrieve all task sheets, and resources for a unit"
  def index
    unless authenticated?
      error!({ error: "Not authorised to download task sheets and resources for unit '#{params[:id]}'" }, 401)
    end

    unit = Unit.find(params[:id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: "Not authorised to download resources for unit '#{params[:id]}'" }, 401)
    end

    output_zip = unit.get_task_resources_zip

    error!({ error: 'No files to download' }, 403) if output_zip.nil?

    download_id = "#{Time.zone.now.strftime('%Y-%m-%d %H:%m:%S')}-resources-#{unit.code}"
    download_id.gsub! /[\\\/]/, '-'
    download_id = FileHelper.sanitized_filename(download_id)

    send_file output_zip, content_type: 'application/octet-stream', disposition: "attachment; filename=#{download_id}.zip"
  rescue MyException => e
    render json: e.message, status: e.status
  end
end
