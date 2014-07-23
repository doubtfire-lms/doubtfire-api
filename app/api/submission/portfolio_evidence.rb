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
    class PortfolioEvidence < Grape::API
      helpers GenerateHelpers
      helpers AuthHelpers
      helpers AuthorisationHelpers
    
      before do
        authenticated?
      end
      
      desc "Upload and generate doubtfire-task-specific submission document"
      params do
        requires :file0, type: Rack::Multipart::UploadedFile, :desc => "file 1."
      end
      post '/submission/task/:id' do

        task = Task.find(params[:id])
        
        if task.discuss? or task.complete? or task.fix_and_include?
          msg = { :complete => "is already complete", :discuss => "is ready to discuss with your tutor", :fix_and_include => "has been marked as fix and include. You may no longer submit this task." }
          error!({"error" => "#{task.task_definition.name} #{msg[task.status]} "}, 401)
        end
        
        upload_reqs = task.upload_requirements
        student = task.project.student
        unit = task.project.unit
        
        # The filepath where to store this upload...
        file_server = Doubtfire::Application.config.file_server_location
        dst = "#{file_server}/#{unit.code}-#{unit.id}/#{student.username}/#{task.task_definition.abbreviation}.pdf"
        
        # Make that directory should it not exist
        FileUtils.mkdir_p(File.dirname(dst))
        
        # Remember to delete the file as we don't want to save it with this kind of inspecific request
        file = combine_to_pdf(scoop_files(params, upload_reqs))
        FileUtils.cp file.path, dst
        
        # This task is now ready to submit
        task.trigger_transition 'ready_to_mark', current_user
        task = Task.update(task.id, :portfolio_evidence => dst)
        
        # +===== TEMPORARY =====+
        resp = file.read
        file.unlink
        content_type "application/octet-stream"
        env['api.format'] = :binary
        resp
        # +===== RELEASE   =====+
        #file.unlink
        #TaskSubmitSerializer.new(task)
        
      end #post
      
      desc "Retrieve submission document included for the task id"
      get '/submission/task/:id' do
        task = Task.find(params[:id])        
        evidence_loc = task.portfolio_evidence
        student = task.project.student
        unit = task.project.unit
        
        if evidence_loc.nil?
          error!({"error" => "No submission under task '#{task.task_definition.name}' for user #{student.username}"}, 401)
        end
        if not authorise? current_user, task, :get_submission
          error!({"error" => "Not authorised to get task '#{task.task_definition.name}' for user #{student.username}"}, 401)
        end
        
        # Set download headers...
        content_type "application/octet-stream"
        header['Content-Disposition'] = "attachment; filename=#{task.task_definition.abbreviation}.pdf"
        env['api.format'] = :binary

        File.read(evidence_loc)
      end
      
      desc "Retrieve all submission documents ready to mark for the provided user's tutorials"
      params do
        requires :user_id, type: Integer, :desc => "User id to fetch ready to mark work to."
      end
      get '/submission/assess/' do
        if not authorise? current_user, Task, :get_ready_to_mark_submissions
          error!({"error" => "Not authorised to batch download ready to mark submissions"}, 401)
        end
        
        ready_to_mark = UnitRole.tasks_ready_to_mark(current_user)
        
        if evidence_loc.nil?
          error!({"error" => "No submission under task '#{task.task_definition.name}' for user #{student.username}"}, 401)
        end
        if not authorise? current_user, task, :get_submission
          error!({"error" => "Not authorised to get task '#{task.task_definition.name}' for user #{student.username}"}, 401)
        end
        
        # Set download headers...
        content_type "application/octet-stream"
        header['Content-Disposition'] = "attachment; filename=#{task.task_definition.abbreviation}.pdf"
        env['api.format'] = :binary

        File.read(evidence_loc)
      end #get
    end
  end
end