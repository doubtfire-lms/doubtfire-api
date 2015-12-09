require 'grape'

class PortfolioDownloadsController < ApplicationController
	include AuthHelpers
	include AuthorisationHelpers

	class MyException < Exception
		attr :status

		def initialize(status)
			@status = status
		end
	end

	def error!(message, status = options[:default_status], headers = {}, backtrace = [])
		raise MyException.new(status), message
	end

	# desc "Retrieve portfolios for a unit"
	def index
		begin
			if not authenticated?
				error!({"error" => "Not authorised to download portfolios for unit '#{params[:id]}'"}, 401)
			end

		    unit = Unit.find(params[:id])

		    if not authorise? current_user, unit, :provide_feedback
		      error!({"error" => "Not authorised to download portfolios for unit '#{params[:id]}'"}, 401)
		    end

		    output_zip = unit.get_portfolio_zip(current_user)

		    if output_zip.nil?
		      error!({"error" => "No files to download"}, 403)
		    end
		    
		    # Set download headers...
		    # content_type "application/octet-stream"
		    download_id = "#{Time.new.strftime("%Y-%m-%d %H:%m:%S")}-portfolios-#{unit.code}-#{current_user.username}"
		    download_id.gsub! /[\\\/]/, '-'
		    download_id = FileHelper.sanitized_filename(download_id)
		    # header['Content-Disposition'] = "attachment; filename=#{download_id}.zip"
		    # env['api.format'] = :binary

		    # puts "Downloading portfolios from #{output_zip.path}"

		    # out = File.open(output_zip.path, "rb")
		    #output_zip.unlink
		    # response_body = out.read
		    # File.binread output_zip.path
		    # sending_file = true

		    send_file output_zip.path, :content_type => "application/octet-stream", :disposition => "attachment; filename=#{download_id}.zip"
		rescue MyException => e
			render json: e.message, status: e.status
		end
	end
end