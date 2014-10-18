require 'grape'
require 'project_serializer'

module Api
  module Submission
    class PortfolioEvidenceApi < Grape::API
      helpers GenerateHelpers
      helpers AuthHelpers
      helpers AuthorisationHelpers
    
      before do
        authenticated?
      end
      
      desc "Upload and generate doubtfire-task-specific submission document"
      params do
        requires :file0, type: Rack::Multipart::UploadedFile, :desc => "file 0."
        optional :file1, type: Rack::Multipart::UploadedFile, :desc => "file 1."
      end
      post '/submission/task/:id' do
        task = Task.find(params[:id])

        if not authorise? current_user, task, :make_submission
          error!({"error" => "Not authorised to submit task '#{task.task_definition.name}'"}, 401)
        end

        if task.discuss? || task.complete? || task.fix_and_include?
          msg = { :complete => "is already complete", :discuss => "is ready to discuss with your tutor", :fix_and_include => "has been marked as fix and include. You may no longer submit this task" }
          error!({"error" => "#{task.task_definition.name} #{msg[task.status]}."}, 401)
        end
        
        upload_reqs = task.upload_requirements
        student = task.project.student
        unit = task.project.unit
        
        # Copy files to be PDFed
        PortfolioEvidence.produce_student_work(scoop_files(params, upload_reqs), student, task, self)
        
        # This task is now ready to submit
        task.trigger_transition 'ready_to_mark', current_user

        TaskUpdateSerializer.new(task)
      end #post
      
      desc "Retrieve submission document included for the task id"
      get '/submission/task/:id' do
        task = Task.find(params[:id])        

        if not authorise? current_user, task, :get_submission
          error!({"error" => "Not authorised to get task '#{task.task_definition.name}'"}, 401)
        end

        evidence_loc = task.portfolio_evidence
        student = task.project.student
        unit = task.project.unit
        
        if evidence_loc.nil? || task.processing_pdf
          error!({"error" => "No submission under task '#{task.task_definition.name}' for user #{student.username}"}, 401)
        end
        
        # Set download headers...
        content_type "application/octet-stream"
        header['Content-Disposition'] = "attachment; filename=#{task.task_definition.abbreviation}.pdf"
        env['api.format'] = :binary

        File.read(evidence_loc)
      end # get
    end
  end
end