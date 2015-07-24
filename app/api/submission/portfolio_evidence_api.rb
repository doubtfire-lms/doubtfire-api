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
        optional :contributions, type: String, :desc => "Contribution details stringified json, eg: [ { project_id: 1, pct:'0.44' }, ... ]"
      end
      post '/submission/task/:id' do
        task = Task.find(params[:id])

        if not authorise? current_user, task, :make_submission
          error!({"error" => "Not authorised to submit task '#{task.task_definition.name}'"}, 401)
        end

        if task.group_task? and not task.group
          error!({"error" => "This task requires a group submission. Ensure you are in a group for the unit's #{task.task_definition.group_set.name}"}, 401)
        end

        if params[:contributions]
          params[:contributions] = JSON.parse(params[:contributions])
        end
        
        upload_reqs = task.upload_requirements
        student = task.project.student
        unit = task.project.unit
        
        task.accept_new_submission(current_user, propagate=true, params[:contributions])

        # Copy files to be PDFed
        PortfolioEvidence.produce_student_work(scoop_files(params, upload_reqs), student, task, self)

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

      desc "Request for a task's documents to be re-processed tp recreate the task's PDF"
      put '/submission/task/:id' do
        task = Task.find(params[:id])        

        if not authorise? current_user, task, :get_submission
          error!({"error" => "Not authorised to get task '#{task.task_definition.name}'"}, 401)
        end

        if task and PortfolioEvidence.recreate_task_pdf(task)
          { result: "done" }
        else
          { result: "false" }
        end
      end # put
    end
  end
end
