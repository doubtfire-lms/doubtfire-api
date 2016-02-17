require 'grape'

class LectureResourceDownloadsController < ApplicationController
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

	# desc "Retrieve all task sheets, and resources for a unit"
	def index
		begin
			if not authenticated?
				error!({"error" => "Not authorised to download task sheets and resources for unit '#{params[:id]}'"}, 401)
			end

		    unit = Unit.find(params[:id])

		    if not authorise? current_user, unit, :get_unit
		      error!({"error" => "Not authorised to download resources for unit '#{params[:id]}'"}, 401)
		    end

		    output_zip = unit.get_task_resources_zip()

		    if output_zip.nil?
		      error!({"error" => "No files to download"}, 403)
		    end
		    
		    download_id = "#{Time.new.strftime("%Y-%m-%d %H:%m:%S")}-resources-#{unit.code}"
		    download_id.gsub! /[\\\/]/, '-'
		    download_id = FileHelper.sanitized_filename(download_id)

		    send_file output_zip.path, :content_type => "application/octet-stream", :disposition => "attachment; filename=#{download_id}.zip"
		rescue MyException => e
			render json: e.message, status: e.status
		end
	end
end