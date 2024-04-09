require 'grape'
require 'zip'
require 'mime/types'
class NumbasApi < Grape::API
  # Include the AuthenticationHelpers for authentication functionality
  helpers AuthenticationHelpers

  before do
    authenticated?
  end

  helpers do
    # Method to stream a file from a zip archive at the specified path
    # @param zip_path [String] the path to the zip archive
    # @param file_path [String] the path of the file within the zip archive
    def stream_file_from_zip(zip_path, file_path)
      file_stream = nil

      # Get an input stream for the requested file within the ZIP archive
      Zip::File.open(zip_path) do |zip_file|
        zip_file.each do |entry|
          logger.debug "Entry name: #{entry.name}"
          if entry.name == file_path
            file_stream = entry.get_input_stream
            break
          end
        end
      end

      # If the file was not found in the ZIP archive, return a 404 response
      unless file_stream
        error!({ error: 'File not found' }, 404)
      end

      # Set the content type based on the file extension
      content_type = MIME::Types.type_for(file_path).first.content_type
      logger.debug "Content type: #{content_type}"

      # Set the content type header
      header 'Content-Type', content_type

      # Set cache control header to prevent caching
      header 'Cache-Control', 'no-cache, no-store, must-revalidate'

      # Set the body to the contents of the file_stream and return the response
      body file_stream.read
    end
  end

  desc 'Start streaming the Numbas test from the index.html'
  params do
    requires :unit_id, type: Integer, desc: 'The unit to modify tasks for'
    requires :task_def_id, type: Integer, desc: 'The task definition to get the Numbas test data of'
  end
  get 'numbas_api/units/:unit_id/task_definitions/:task_def_id/index.html' do
    env['api.format'] = :txt
    unit = Unit.find(params[:unit_id])
    task_def = unit.task_definitions.find(params[:task_def_id])
    if task_def.has_numbas_data?
      zip_path = task_def.task_numbas_data
      content_type 'application/octet-stream'
    else
      error!({ error: 'Numbas data does not exist.' }, 401)
    end
    stream_file_from_zip(zip_path, 'index.html')
  end

  desc 'Start streaming the Numbas test from the specified file'
  params do
    requires :unit_id, type: Integer, desc: 'The unit to modify tasks for'
    requires :task_def_id, type: Integer, desc: 'The task definition to get the Numbas test data of'
  end
  get 'numbas_api/units/:unit_id/task_definitions/:task_def_id/*file_path' do
    env['api.format'] = :txt
    unit = Unit.find(params[:unit_id])
    task_def = unit.task_definitions.find(params[:task_def_id])
    if task_def.has_numbas_data?
      zip_path = task_def.task_numbas_data
      content_type 'application/octet-stream'
    else
      error!({ error: 'Numbas data does not exist.' }, 401)
    end
    requested_file_path = "#{params[:file_path]}.#{params[:format]}"
    stream_file_from_zip(zip_path, requested_file_path)
  end
end
