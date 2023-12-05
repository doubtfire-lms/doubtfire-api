require 'grape'
require 'zip'
require 'mime/types'
class NumbasApi < Grape::API
  # Include the AuthenticationHelpers for authentication functionality
  helpers AuthenticationHelpers

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

  # Define the API namespace
  namespace :numbas_api do
    # Use Grape's before hook to check authentication before processing any route
    before do
      authenticated?
    end

    get '/index.html' do
      env['api.format'] = :txt
      zip_path = FileHelper.get_numbas_test_path(params[:unit_code], params[:task_definition_id], 'numbas_test.zip')
      stream_file_from_zip(zip_path, 'index.html')
    end

    get '*file_path' do
      env['api.format'] = :txt
      zip_path = FileHelper.get_numbas_test_path(params[:unit_code], params[:task_definition_id], 'numbas_test.zip')
      requested_file_path = "#{params[:file_path]}.#{params[:format]}"
      stream_file_from_zip(zip_path, requested_file_path)
    end

    post '/uploadNumbasTest' do
      # Ensure the uploaded file is present
      unless params[:file] && params[:file][:tempfile]
        error!({ error: 'File upload is missing' }, 400)
      end

      # Use the FileHelper to save the uploaded test
      save_path = FileHelper.get_numbas_test_path(params[:unit_code], params[:task_definition_id], 'numbas_test.zip')
      File.binwrite(save_path, params[:file][:tempfile].read)

      { success: true, message: 'File uploaded successfully' }
    end
  end
end
