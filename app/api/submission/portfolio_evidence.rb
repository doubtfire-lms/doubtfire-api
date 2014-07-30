require 'grape'
require 'project_serializer'

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
        requires :file0, type: Rack::Multipart::UploadedFile, :desc => "file 0."
        optional :file1, type: Rack::Multipart::UploadedFile, :desc => "file 1."
      end
      post '/submission/task/:id' do
        task = Task.find(params[:id])

        if task.discuss? || task.complete? || task.fix_and_include?
          msg = { :complete => "is already complete", :discuss => "is ready to discuss with your tutor", :fix_and_include => "has been marked as fix and include. You may no longer submit this task" }
          error!({"error" => "#{task.task_definition.name} #{msg[task.status]}."}, 401)
        end
        
        upload_reqs = task.upload_requirements
        student = task.project.student
        unit = task.project.unit
        
        # The filepath where to store this upload...
        dst = student_work_dir(unit, student, task)

        # Remember to delete the file as we don't want to save it with this kind of inspecific request
        file = combine_to_pdf(scoop_files(params, upload_reqs), student)
        FileUtils.cp file.path, dst
        
        # This task is now ready to submit
        task.trigger_transition 'ready_to_mark', current_user
        
        # Remove the tempfile and set portfolio_evidence to the stored file directory
        file.unlink
        task = Task.update(task.id, :portfolio_evidence => dst)

        TaskUpdateSerializer.new(task)
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
      end # get
    end
  end
end