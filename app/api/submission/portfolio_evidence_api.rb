require 'grape'

module Submission
  class PortfolioEvidenceApi < Grape::API
    helpers GenerateHelpers
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    helpers FileStreamHelper
    helpers Base64Helper

    include LogHelper

    def self.logger
      LogHelper.logger
    end

    before do
      authenticated?
    end

    TASK_STATES = {
      ready_for_feedback: 1,
      assess_in_portfolio: 1,
      discuss: 2,
      rediscuss: 2,
      attention_required: 0,
      demonstrate: 2,
      complete: 3
    }.freeze

    desc 'Upload and generate doubtfire-task-specific submission document'
    params do
      optional :file0, type: File, desc: 'file 0.'
      optional :file1, type: File, desc: 'file 1.'
      optional :contributions, type: JSON, desc: "Contribution details JSON, eg: [ { project_id: 1, pct:'0.44', pts: 4 }, ... ]"
      optional :alignment_data, type: JSON, desc: "Data for task alignment, eg: [ { ilo_id: 1, rating: 5, rationale: 'Hello' }, ... ]"
      optional :trigger, type: String, desc: 'Can be need_help to indicate upload is not a ready to mark submission'
      optional :accepted_tii_eula, type: Boolean, desc: 'Whether or not the user has accepted the TII EULA as part of the submission.'
      optional :comment, type: String, desc: 'Comment to be added together with the submission'
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

      # Check that prerequisite tasks are in the required minimum submitted state
      prerequisites = task_definition.task_prerequisites
      prerequisites.each do |prerequisite|
        prereq_td = prerequisite.prerequisite
        minimum_status = TaskStatus.find(prerequisite.task_status_id)


        prereq_task = project.task_for_task_definition(prereq_td)

        verb =
          case minimum_status
          when TaskStatus.complete
            'completed'
          when TaskStatus.discuss
            'discussed'
          when TaskStatus.rediscuss
            'rediscussed'
          when TaskStatus.demonstrate
            'demonstrated'
          when TaskStatus.ready_for_feedback
            'submitted'
          end

        if !prereq_task.ready_or_complete? || TASK_STATES[prereq_task.status] < TASK_STATES[minimum_status.status_key]
          error!({ error: "Cannot submit this task until prerequisite '#{prereq_td.abbreviation}' has been #{verb}" }, 409)
        end
      end

      trigger = if params[:trigger] && params[:trigger].tr('"\'', '') == 'need_help'
                  'need_help'
                elsif params[:trigger] && params[:trigger].tr('"\'', '') == 'assess_in_portfolio'
                  'assess_in_portfolio'
                else
                  'ready_for_feedback'
                end


      comment = params[:comment]
      comment = comment.strip unless comment.nil?
      if task_definition.assess_in_portfolio_only && comment.blank? && trigger == 'ready_for_feedback'
        error!({ error: 'Please provide a comment requesting specific feedback on your submission.' }, 422)
      end

      task.add_text_comment(current_user, comment) if comment.present?

      alignments = params[:alignment_data]
      upload_reqs = task.upload_requirements

      # Copy files to be PDFed
      task.accept_submission(current_user, scoop_files(params, upload_reqs), self, params[:contributions], trigger, alignments, accepted_tii_eula: params[:accepted_tii_eula])


      present task, with: Entities::TaskEntity, update_only: true
    end
    # post

    desc 'Retrieve submission document included for the task id'
    params do
      optional :as_attachment, type: Boolean, desc: 'Whether or not to download file as attachment. Default is false.'
    end
    get '/projects/:id/task_def_id/:task_definition_id/submission' do
      project = Project.eager_load(:unit).find(params[:id])
      task_definition = project.unit.task_definitions.select(:id, :name, :abbreviation).find(params[:task_definition_id])

      # check the user can put this task
      unless authorise? current_user, project, :get_submission
        error!({ error: "Not authorised to get task '#{task_definition.name}'" }, 401)
      end

      task = project.task_for_task_definition(task_definition)

      evidence_loc = task.final_pdf_path

      if task.processing_pdf?
        evidence_loc = Rails.root.join('public/resources/AwaitingProcessing.pdf')
        filename = 'AwaitingProcessing.pdf'
      elsif evidence_loc.nil? || !File.exist?(evidence_loc)
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

      unless authorise? current_user, project, :reprocess_submission
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

      result = OverseerAssessment.where(submission_history_id: task.related_submission_histories.select(:id))
                                 .order(submission_timestamp: :desc)
                                 .limit(10)
      present result, with: Entities::OverseerAssessmentEntity
    end

    desc 'Get all retained submission histories for a task'
    get '/projects/:id/task_def_id/:task_definition_id/submission_histories' do
      project = Project.find(params[:id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :get_submission
        error!({ error: "Not authorised to get submission history for task '#{task_definition.name}'" }, 401)
      end

      task = project.task_for_task_definition(task_definition)
      unless task
        error!({ error: 'A submission for this task definition has never been created' }, 404)
      end

      present task.related_submission_histories.order(submission_timestamp: :desc),
              with: Entities::SubmissionHistoryEntity
    end

    desc 'Download a retained submission history archive'
    get '/projects/:id/task_def_id/:task_definition_id/submission_histories/:history_id/files' do
      project = Project.find(params[:id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project.unit, :provide_feedback
        error!({ error: "Not authorised to get submission history for task '#{task_definition.name}'" }, 401)
      end

      task = project.task_for_task_definition(task_definition)
      history = task&.related_submission_histories&.find_by(id: params[:history_id])
      error!({ error: 'Submission history was not found' }, 404) unless history
      error!({ error: 'Submission history files are not available' }, 404) unless history.has_submission_files?

      filename = "#{project.student.username}-#{task_definition.abbreviation}-#{history.submission_timestamp}.zip"

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{filename}"
      submission_zip_data = history.submission_zip_data
      header['Content-Length'] = submission_zip_data.bytesize.to_s
      env['api.format'] = :binary
      body submission_zip_data
    end

    desc 'Trigger an overseer assessment to run again'
    put '/projects/:id/task_def_id/:task_definition_id/overseer_assessment/:oa_id/trigger' do
      project = Project.find(params[:id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project, :reprocess_submission
        error!({ error: "Not authorised to get task '#{task_definition.name}'" }, 401)
      end

      task = project.task_for_task_definition(task_definition)

      unless task
        error!({ error: "A submission for this task definition have never been created" }, 401)
      end

      oa_id = timestamp = params[:oa_id]

      oa = OverseerAssessment
           .where(submission_history_id: task.related_submission_histories.select(:id))
           .find(oa_id)
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

      unless File.exist? "#{path}/output.yaml"
        error!({ error: "There is no output for this assessment. Either the output wasn't generated, or processing failed. Please review your submission, and discuss with the teaching team if issues persist." }, 401)
      end

      result = []
      begin
        yaml_data = YAML.load_file("#{path}/output.yaml") # returns a hash
      rescue Psych::SyntaxError => e
        error!({ error: "Failed to parse overseer output: #{e.message}" }, 401)
      end

      yaml_data.each do |key, value|
        if base64?(value)
          value = Base64.decode64(value)
        end
        result << { label: key, result: value }
      end

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

    desc 'Get the submission files zip for the overseer assessment made at the given timestamp'
    params do
      requires :timestamp, type: Integer, desc: 'The submission timestamp for the overseer assessment'
    end
    get '/projects/:id/task_def_id/:task_definition_id/submissions/timestamps/:timestamp/files' do
      project = Project.find(params[:id])
      task_definition = project.unit.task_definitions.find(params[:task_definition_id])

      unless authorise? current_user, project.unit, :provide_feedback
        error!({ error: "Not authorised to get task '#{task_definition.name}'" }, 401)
      end

      task = project.task_for_task_definition(task_definition)
      unless task
        error!({ error: 'A submission for this task definition have never been created' }, 401)
      end

      history = task.related_submission_histories.find_by(submission_timestamp: params[:timestamp])
      unless history
        error!({ error: "No submission history found for timestamp '#{params[:timestamp]}'" }, 404)
      end

      unless history.has_submission_files?
        error!({ error: "No submission files are available for timestamp '#{params[:timestamp]}'" }, 404)
      end

      filename = "#{project.student.username}-#{task.task_definition.abbreviation}-#{params[:timestamp]}.zip"

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{filename}"

      submission_zip_data = history.submission_zip_data
      header['Content-Length'] = submission_zip_data.bytesize.to_s
      env['api.format'] = :binary
      body submission_zip_data
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

      unless File.exist? "#{path}/output.yaml"
        error!({ error: "There is no output for this assessment. Either the output wasn't generated, or processing failed. Please review your submission, and discuss with the teaching team if issues persist." }, 401)
      end

      result = []
      begin
        yaml_data = YAML.load_file("#{path}/output.yaml") # returns a hash
      rescue Psych::SyntaxError => e
        error!({ error: "Failed to parse overseer output: #{e.message}" }, 401)
      end

      yaml_data.each do |key, value|
        if base64?(value)
          value = Base64.decode64(value)
        end
        result << { label: key, result: value }
      end

      if project.role_for(current_user) == :student
        present result, with: Grape::Presenters::Presenter
        return
      end

      # if File.exist? "#{path}/build-diff.txt"
      #   result << { label: 'build-diff', result: File.read("#{path}/build-diff.txt") }
      # end

      # if File.exist? "#{path}/run-diff.txt"
      #   result << { label: 'run-diff', result: File.read("#{path}/run-diff.txt") }
      # end

      present result, with: Grape::Presenters::Presenter
    end
  end
end
