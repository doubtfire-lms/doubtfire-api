require 'grape'

class PortfolioDownloadsController < ApplicationController
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

  # desc "Retrieve portfolios for a unit"
  def index
    unless authenticated?
      error!({ error: "Not authorised to download portfolios for unit '#{params[:id]}'" }, 401)
    end

    unit = Unit.find(params[:id])

    unless authorise? current_user, unit, :get_students
      error!({ error: "Not authorised to download portfolios for unit '#{params[:id]}'" }, 401)
    end

    output_zip = unit.get_portfolio_zip(current_user)

    error!({ error: 'No files to download' }, 403) if output_zip.nil?

    # Set download headers...
    # content_type "application/octet-stream"
    download_id = "#{Time.zone.now.strftime('%Y-%m-%d %H:%m:%S')}-portfolios-#{unit.code}-#{current_user.username}"
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

    send_file output_zip, content_type: 'application/octet-stream', disposition: "attachment; filename=#{download_id}.zip"
  rescue MyException => e
    render json: e.message, status: e.status
  end
end
