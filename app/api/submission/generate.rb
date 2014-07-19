require 'grape'

# Temporarily...
require 'json'

require 'project_serializer'

# getting file info
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
      helpers AuthHelpers
      helpers AuthorisationHelpers
  
      before do
#         authenticated?
      end
  
      desc "Upload and generate submission document"
      params do
        #requires :file_details, type: JSON, :desc => "File details, eg: [ { key: 'file1', name: 'Shape Class', type: '[image/code/document]' }, ... ]"
        requires :file1, type: Rack::Multipart::UploadedFile, :desc => "file 1."
        requires :file2, type: Rack::Multipart::UploadedFile, :desc => "file 2."
        requires :file3, type: Rack::Multipart::UploadedFile, :desc => "file 3."
      end
      post '/submission/generate/' do

        # DEBUG... using file_details hard-coded for now...
        params[:file_details] = JSON.parse '[ { "key": "file1", "name": "Shape Image", "type": "code" }, { "key": "file2", "name": "Shape Class", "type": "code" }, { "key":"file3", "name":"Shape Document", "type":"document" } ]'
        
        # scoop out the files into an easier to work with array
        files = params.reject { | key | not key =~ /file\d+/ }
        
        #
        # Pair the name and type from file_details to each file
        #
        params[:file_details].each do | detail |
          files[detail['key']].id   = files[detail['key']].name
          files[detail['key']].name = detail['name']
          files[detail['key']].type = detail['type']
        end
        
        
        
        #
        # Process each file...
        #
        output_files = []
        files.map{ | k, v | v }.each do | file |
          
          #
          # Firstly, confirm subtype categories using filemagic
          #
          fm = FileMagic.new(FileMagic::MAGIC_MIME)
          mime = fm.file file.tempfile.path

          case file.type
          when 'image'
            accept = ["image/png", "image/gif", "image/bmp", "image/tiff", "image/jpeg"]
          when 'code'
            accept = ["text/x-pascal", "text/x-c", "text/x-c++", "text/plain"]
          when 'document'
            accept = ["application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                      "application/msword", "application/pdf"]
          else
            error!({"error" => "Unknown type #{file.type} for '#{file.name}'"}, 403)
          end
          
          if not mime.start_with?(*accept)
            error!({"error" => "'#{file.name}' has a bad #{file.type} type"}, 403)
          end
          
          #
          # Once confirmed, compile a PDF using any means
          #
          output_file = Tempfile.new(file.filename).open
          
          case file.type
          #
          # img -> pdf
          #
          when 'image'
            Magick::Image.read(file.tempfile.path).first.write(output_file.path)
          #
          # code -> html -> pdf
          #
          when 'code'
            # decide language syntax highlighting
            case File.extname(file.filename)
            when '.cpp', '.cs'
              lang = :cplusplus
            when '.c'
              lang = :c
            when '.java'
              lang = :java
            when '.pas'
              lang = :delphi
            else
              lang = :plain
            end
            # create html content
            html = CodeRay.scan_file(file.tempfile, lang).html(:tab_width => 2, :css => :class, :title => file.name)
            puts html
            # new kit
            #kit = PDFKit.new(html, :page_size => 'A4')
            #output_file = kit.to_pdf
          end
          
# Word To PDF
# todo

# Code To PDF
# CodeRay.scan_file(file.tempfile, <lang> { :cpp, :c, :delphi }).page(:tab_width => 2)

          
        end
      end
  
      desc "Get users"
      params do
        requires :unit_id, type: Integer, desc: 'The unit to get the students for'
      end
      get '/students' do
        #TODO: authorise!
        unit = Unit.find(params[:unit_id])
  
        if authorise? current_user, unit, :get_students
          result = unit.students #, each_serializer: ShallowProjectSerializer
          ActiveModel::ArraySerializer.new(result, each_serializer: StudentProjectSerializer)
        else
          error!({"error" => "Couldn't find Unit with id=#{params[:unit_id]}" }, 403)
        end
      end
    end  
  end
end
