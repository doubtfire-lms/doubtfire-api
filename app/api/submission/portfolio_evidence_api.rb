require 'grape'
require 'project_serializer'

module Api
  module Submission
    class PortfolioEvidenceApi < Grape::API
      helpers GenerateHelpers
      helpers AuthenticationHelpers
      helpers AuthorisationHelpers

      before do
        authenticated?
      end

      desc 'Upload and generate doubtfire-task-specific submission document'
      params do
        optional :file0, type: Rack::Multipart::UploadedFile, desc: 'file 0.'
        optional :file1, type: Rack::Multipart::UploadedFile, desc: 'file 1.'
        optional :contributions, type: JSON, desc: "Contribution details JSON, eg: [ { project_id: 1, pct:'0.44', pts: 4 }, ... ]"
        optional :alignment_data, type: JSON, desc: "Data for task alignment, eg: [ { ilo_id: 1, rating: 5, rationale: 'Hello' }, ... ]"
        optional :trigger, type: String, desc: 'Can be need_help to indicate upload is not a ready to mark submission'
      end
      post '/projects/:id/task_def_id/:task_definition_id/submission' do
        project = Project.find(params[:id])
        task_definition = project.unit.task_definitions.find(params[:task_definition_id])

        # check the user can put this task
        unless authorise? current_user, project, :make_submission
          error!({ error: "Not authorised to submit task '#{task_definition.name}'" }, 401)
        end

        task = project.task_for_task_definition(task_definition)

        if task.group_task? && !task.group
          error!({ error: "This task requires a group submission. Ensure you are in a group for the unit's #{task_definition.group_set.name}" }, 403)
        end

        trigger = if params[:trigger] && params[:trigger].tr('"\'', '') == 'need_help'
                    'need_help'
                  else
                    'ready_to_mark'
                  end

        alignments = params[:alignment_data]
        upload_reqs = task.upload_requirements
        student = task.project.student
        unit = task.project.unit

        # Copy files to be PDFed
        task.accept_submission(current_user, scoop_files(params, upload_reqs), student, self, params[:contributions], trigger, alignments)

        TaskUpdateSerializer.new(task)
      end # post

      desc 'Retrieve submission document included for the task id'
      params do
        optional :as_attachment, type: Boolean, desc: 'Whether or not to download file as attachment. Default is false.'
      end
      get '/projects/:id/task_def_id/:task_definition_id/submission' do
        project = Project.find(params[:id])
        task_definition = project.unit.task_definitions.find(params[:task_definition_id])

        # check the user can put this task
        unless authorise? current_user, project, :get_submission
          error!({ error: "Not authorised to get task '#{task_definition.name}'" }, 401)
        end

        task = project.task_for_task_definition(task_definition)

        evidence_loc = task.portfolio_evidence
        student = task.project.student
        unit = task.project.unit

        if task.processing_pdf?
          evidence_loc = Rails.root.join('public', 'resources', 'AwaitingProcessing.pdf')
          filename='AwaitingProcessing.pdf'
        elsif evidence_loc.nil?
          evidence_loc = Rails.root.join('public', 'resources', 'FileNotFound.pdf')
          filename='FileNotFound.pdf'
        else
          filename="#{task.task_definition.abbreviation}.pdf"
        end


        if params[:as_attachment]
          header['Content-Disposition'] = "attachment; filename=#{filename}"
        end

        # Set download headers...
        content_type 'application/pdf'
        env['api.format'] = :binary

        File.read(evidence_loc)
      end # get

      desc "Request for a task's documents to be re-processed tp recreate the task's PDF"
      put '/projects/:id/task_def_id/:task_definition_id/submission' do
        project = Project.find(params[:id])
        task_definition = project.unit.task_definitions.find(params[:task_definition_id])

        unless authorise? current_user, project, :get_submission
          error!({ error: "Not authorised to get task '#{task_definition.name}'" }, 401)
        end

        task = project.task_for_task_definition(task_definition)

        if task && PortfolioEvidence.recreate_task_pdf(task)
          { result: 'done' }
        else
          { result: 'false' }
        end
      end # put
    end
  end
end
