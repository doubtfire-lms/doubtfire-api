require 'grape'
require 'zip'
require 'mime/types'
class ScormApi < Grape::API
  # Include the AuthenticationHelpers for authentication functionality
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated? :scorm
  end

  helpers do
    # Method to stream a file from a zip archive at the specified path
    # @param zip_path [String] the path to the zip archive
    # @param file_path [String] the path of the file within the zip archive
    def stream_file_from_zip(zip_path, file_path)
      file_stream = nil

      logger.debug "Streaming zip file at #{zip_path}"
      # Get an input stream for the requested file within the ZIP archive
      Zip::File.open(zip_path) do |zip_file|
        zip_file.each do |entry|
          next unless entry.name == file_path
          logger.debug "Found file #{file_path} from SCORM container"
          file_stream = entry.get_input_stream
          break
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

  desc 'Serve SCORM content'
  params do
    requires :task_def_id, type: Integer, desc: 'Task Definition ID to get SCORM test data for'
  end
  get '/scorm/:task_def_id/:username/:auth_token/*file_path' do
    task_def = TaskDefinition.find(params[:task_def_id])

    unless authorise? current_user, task_def.unit, :get_unit
      error!({ error: 'You cannot access SCORM tests of unit' }, 403)
    end

    env['api.format'] = :txt
    if task_def.has_scorm_data?
      zip_path = task_def.task_scorm_data
      content_type 'application/octet-stream'
      stream_file_from_zip(zip_path, params[:file_path])
    else
      error!({ error: 'SCORM data does not exist.' }, 404)
    end
  end
end
