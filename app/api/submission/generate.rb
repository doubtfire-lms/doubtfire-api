require 'grape'
require 'project_serializer'

# Temporarily...
require 'json'
$mock_data = JSON.parse '[ { "key": "file0", "name": "Shape Image", "type": "image" }, { "key": "file1", "name": "Shape Class", "type": "code" }, { "key":"file2", "name":"Shape Document", "type":"document" } ]'

# getting file MIME types
require 'filemagic'
# image to pdf
require 'RMagick'
# code to html
require 'coderay'
# html to pdf
require 'pdfkit'

module Api
  module Submission
    class Generate < Grape::API
      helpers GenerateHelpers
  
      desc "Generate doubtfire-task-inspecific submission document"
      params do
        requires :upload_requirements, type: JSON, :desc => "File details, eg: [ { key: 'file1', name: 'Shape Class', type: '[image/code/document]' }, ... ]"
        requires :file0, type: Rack::Multipart::UploadedFile, :desc => "file 1."
      end
      post '/submission/generate/' do

        # Set download headers...
        content_type "application/octet-stream"
        header['Content-Disposition'] = "attachment; filename=output.pdf"
        env['api.format'] = :binary
        
        file = combine_to_pdf(scoop_files(params, params[:upload_requirements]))
        file.path
        response = file.open.read
        
        # Remember to delete the file as we don't want to save it with this kind of inspecific request
        file.unlink
        
        response
      end
    end
  end
end