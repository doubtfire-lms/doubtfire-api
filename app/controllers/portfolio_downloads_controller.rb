require 'grape'

class PortfolioDownloadsController < ApplicationController
  include AuthenticationHelpers
  include AuthorisationHelpers
  include LogHelper
  include DownloadAuthorization
  include NativeDownloadCookie

  class MyException < RuntimeError
    attr_reader :status

    def initialize(status)
      @status = status
    end
  end

  def error!(message, status = options[:default_status], _headers = {}, _backtrace = [])
    raise MyException.new(status), message
  end

  # desc "Retrieve portfolios for a unit"
  def index
    download_user = native_download_user(:portfolio, unit_id: params[:id].to_i)

    unless download_user
      error!({ error: "Not authorised to download portfolios for unit '#{params[:id]}'" }, 401)
    end

    unit = Unit.find(params[:id])

    unless authorise? download_user, unit, :get_students
      error!({ error: "Not authorised to download portfolios for unit '#{params[:id]}'" }, 401)
    end

    output_zip = unit.get_portfolio_zip_filename(download_user)
    error!({ error: 'No files to download' }, 403) unless File.exist?(output_zip)

    # Set download headers...
    # content_type "application/octet-stream"
    download_id = "#{Time.zone.now.strftime('%Y-%m-%d %H:%M:%S')}-portfolios-#{unit.code}-#{download_user.username}"
    download_id.gsub! /[\\\/]/, '-'
    download_id = FileHelper.sanitized_filename(download_id)
    # header['Content-Disposition'] = "attachment; filename=#{download_id}.zip"
    # env['api.format'] = :binary

    logger.debug "Downloading portfolios from #{output_zip}"

    # out = File.open(output_zip, "rb")
    # output_zip.unlink
    # response_body = out.read
    # File.binread output_zip
    # sending_file = true

    send_download output_zip, filename: "#{download_id}.zip", type: 'application/zip'
  rescue MyException => e
    render json: e.message, status: e.status
  end
end
