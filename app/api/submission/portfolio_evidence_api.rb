require 'grape'

module Submission
  class PortfolioEvidenceApi < Grape::API
    helpers GenerateHelpers
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    helpers FileStreamHelper
    include LogHelper

    def self.logger
      LogHelper.logger
    end

    before do
      authenticated?
    end

    desc 'Upload and generate doubtfire-task-specific submission document'
    params do
      optional :file0, type: File, desc: 'file 0.'
      optional :file1, type: File, desc: 'file 1.'
      optional :contributions, type: JSON, desc: "Contribution details JSON, eg: [ { project_id: 1, pct:'0.44', pts: 4 }, ... ]"
      optional :alignment_data, type: JSON, desc: "Data for task alignment, eg: [ { ilo_id: 1, rating: 5, rationale: 'Hello' }, ... ]"
      optional :trigger, type: String, desc: 'Can be need_help to indicate upload is not a ready to mark submission'
      optional :accepted_tii_eula, type: Boolean, desc: 'Whether or not the user has accepted the TII EULA as part of the submission.'
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
                  'ready_for_feedback'
                end

      alignments = params[:alignment_data]
      upload_reqs = task.upload_requirements

      # Copy files to be PDFed
      task.accept_submission(current_user, scoop_files(params, upload_reqs), self, params[:contributions], trigger, alignments, accepted_tii_eula: params[:accepted_tii_eula])

      if task.overseer_enabled?
        overseer_assessment = OverseerAssessment.create_for(task)
        if overseer_assessment.present?
          logger.info "Launching Overseer assessment for task_def_id: #{task_definition.id} task_id: #{task.id}"

          response = overseer_assessment.send_to_overseer

          if response[:error].present?
            error!({ error: response[:error] }, 403)
          end
        else
          logger.info "Overseer assessment for task_def_id: #{task_definition.id} task_id: #{task.id} was not performed"
        end
      end

      present task, with: Entities::TaskEntity, update_only: true
    end
    # post

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

      evidence_loc = task.portfolio_evidence_path
      student = task.project.student
      unit = task.project.unit

      if task.processing_pdf?
        evidence_loc = Rails.root.join('public/resources/AwaitingProcessing.pdf')
        filename = 'AwaitingProcessing.pdf'
      elsif evidence_loc.nil?
        evidence_loc = Rails.root.join('public/resources/FileNotFound.pdf')
        filename = 'FileNotFound.pdf'
      else
        filename = "#{task.task_definition.abbreviation}.pdf"
      end

      if params[:as_attachment]
        header['Content-Disposition'] = "attachment; filename=#{filename}"
      end

      # Set download headers...
      content_type 'application/pdf'

      stream_file evidence_loc
    end # get

    desc "Request for a task's documents to be re-processed to recreate the task's PDF"
    put '/projects/:id/task_def_id/:task_definition_id/submission' do
      project = Project.find(params[:id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :get_submission
        error!({ error: "Not authorised to get task '#{task_definition.name}'" }, 401)
      end

      task = project.task_for_task_definition(task_definition)

      if task && PortfolioEvidence.recreate_task_pdf(task)
        result = 'done'
      else
        result = 'false'
      end

      present :result, result, with: Grape::Presenters::Presenter
    end # put

    desc 'Get the timestamps of the last 10 submissions of a task'
    get '/projects/:id/task_def_id/:task_definition_id/submissions/timestamps' do
      project = Project.find(params[:id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :get_submission
        error!({ error: "Not authorised to get task '#{task_definition.name}'" }, 401)
      end

      task = project.task_for_task_definition(task_definition)

      unless task
        error!({ error: "A submission for this task definition have never been created" }, 401)
      end

      result = OverseerAssessment.where(task_id: task.id).order(submission_timestamp: :desc).limit(10)
      present result, with: Entities::OverseerAssessmentEntity
    end

    desc 'Trigger an overseer assessment to run again'
    put '/projects/:id/task_def_id/:task_definition_id/overseer_assessment/:oa_id/trigger' do
      project = Project.find(params[:id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :get_submission
        error!({ error: "Not authorised to get task '#{task_definition.name}'" }, 401)
      end

      task = project.task_for_task_definition(task_definition)

      unless task
        error!({ error: "A submission for this task definition have never been created" }, 401)
      end

      oa_id = timestamp = params[:oa_id]

      oa = task.overseer_assessments.find(oa_id)
      response = oa.send_to_overseer
      if response[:error].present?
        error!({ error: response[:error] }, 403)
      end

      present response[:comment].serialize(current_user), with: Grape::Presenters::Presenter
    end

    desc 'Get the result of the submission of a task made at the given timestamp'
    get '/projects/:id/task_def_id/:task_definition_id/submissions/timestamps/:timestamp' do
      project = Project.find(params[:id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :get_submission
        error!({ error: "Not authorised to get task '#{task_definition.name}'" }, 401)
      end

      task = project.task_for_task_definition(task_definition)

      unless task
        error!({ error: "A submission for this task definition have never been created" }, 401)
      end

      timestamp = params[:timestamp]

      path = FileHelper.task_submission_identifier_path_with_timestamp(:done, task, timestamp)
      unless File.exist? path
        error!({ error: "No submissions found for project: '#{params[:id]}' task: '#{params[:task_def_id]}' and timestamp: '#{timestamp}'" }, 401)
      end

      unless File.exist? "#{path}/output.txt"
        error!({ error: "There is no output for this assessment. Either the output wasn't generated, or processing failed. Please review your submission, and discuss with the teaching team if issues persist." }, 401)
      end

      result = []
      result << { label: 'output', result: File.read("#{path}/output.txt") }

      if project.role_for(current_user) == :student
        return result
      end

      if File.exist? "#{path}/build-diff.txt"
        result << { label: 'build-diff', result: File.read("#{path}/build-diff.txt") }
      end

      if File.exist? "#{path}/run-diff.txt"
        result << { label: 'run-diff', result: File.read("#{path}/run-diff.txt") }
      end

      present result, with: Grape::Presenters::Presenter
    end

    desc 'Get the result of the submission of a task made last'
    get '/projects/:id/task_def_id/:task_definition_id/submissions/latest' do
      project = Project.find(params[:id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :get_submission
        error!({ error: "Not authorised to get task '#{task_definition.name}'" }, 401)
      end

      task = project.task_for_task_definition(task_definition)

      unless task
        error!({ error: "A submission for this task definition have never been created" }, 401)
      end

      path = FileHelper.task_submission_identifier_path(:done, task)
      unless File.exist? path
        error!({ error: "No submissions found for project: '#{params[:id]}' task: '#{params[:task_def_id]}'" }, 401)
      end

      path = "#{path}/#{FileHelper.latest_submission_timestamp_entry_in_dir(path)}"

      unless File.exist? "#{path}/output.txt"
        error!({ error: "There is no output for this assessment. Either the output wasn't generated, or processing failed. Please review your submission, and discuss with the teaching team if issues persist." }, 401)
      end

      result = []
      result << { label: 'output', result: File.read("#{path}/output.txt") }

      if project.role_for(current_user) == :student
        present result, with: Grape::Presenters::Presenter
        return
      end

      if File.exist? "#{path}/build-diff.txt"
        result << { label: 'build-diff', result: File.read("#{path}/build-diff.txt") }
      end

      if File.exist? "#{path}/run-diff.txt"
        result << { label: 'run-diff', result: File.read("#{path}/run-diff.txt") }
      end

      present result, with: Grape::Presenters::Presenter
    end
  end
end
