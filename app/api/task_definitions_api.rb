require 'grape'

class TaskDefinitionsApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers FileHelper
  helpers MimeCheckHelpers
  helpers Submission::GenerateHelpers
  helpers FileStreamHelper

  before do
    authenticated?
  end

  desc 'Add a new task definition to the given unit'
  params do
    requires :task_def, type: Hash do
      optional :tutorial_stream_abbr,     type: String,   desc: 'The abbreviation of tutorial stream'
      requires :name,                     type: String,   desc: 'The name of this task def'
      requires :description,              type: String,   desc: 'The description of this task def'
      requires :weighting,                type: Integer,  desc: 'The weighting of this task'
      requires :target_grade,             type: Integer,  desc: 'Minimum grade for task'
      optional :group_set_id,             type: Integer,  desc: 'Related group set'
      requires :start_date,               type: Date,     desc: 'The date when the task should be started'
      requires :target_date,              type: Date,     desc: 'The date when the task is due'
      optional :due_date,                 type: Date,     desc: 'The deadline date'
      requires :abbreviation,             type: String,   desc: 'The abbreviation of the task'
      requires :restrict_status_updates,  type: Boolean,  desc: 'Restrict updating of the status to staff'
      optional :upload_requirements,      type: String,   desc: 'Task file upload requirements'
      requires :plagiarism_warn_pct,      type: Integer,  desc: 'The percent at which to record and warn about plagiarism'
      requires :is_graded,                type: Boolean,  desc: 'Whether or not this task definition is a graded task'
      requires :max_quality_pts,          type: Integer,  desc: 'A range for quality points when quality is assessed'
      optional :assessment_enabled,       type: Boolean,  desc: 'Enable or disable assessment'
      optional :overseer_image_id,        type: Integer,  desc: 'The id of the Docker image for overseer'
      optional :moss_language,            type: String,   desc: 'The language to use for code similarity checks'
    end
  end
  post '/units/:unit_id/task_definitions/' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :add_task_def
      error!({ error: 'Not authorised to create a task definition of this unit' }, 403)
    end

    params[:task_def][:upload_requirements] = [] if params[:task_def][:upload_requirements].nil?

    task_params = ActionController::Parameters.new(params)
                                              .require(:task_def)
                                              .permit(
                                                :name,
                                                :description,
                                                :weighting,
                                                :target_grade,
                                                :start_date,
                                                :target_date,
                                                :due_date,
                                                :abbreviation,
                                                :restrict_status_updates,
                                                :plagiarism_warn_pct,
                                                :is_graded,
                                                :max_quality_pts,
                                                :assessment_enabled,
                                                :overseer_image_id,
                                                :moss_language
                                              )

    task_params[:unit_id] = unit.id
    task_params[:upload_requirements] = JSON.parse(params[:task_def][:upload_requirements]) unless params[:task_def][:upload_requirements].nil?

    task_def = TaskDefinition.new(task_params)

    # Set the tutorial stream
    tutorial_stream_abbr = params[:task_def][:tutorial_stream_abbr]
    unless tutorial_stream_abbr.nil?
      tutorial_stream = unit.tutorial_streams.find_by!(abbreviation: tutorial_stream_abbr)
      task_def.tutorial_stream = tutorial_stream
    end

    #
    # Link in group set if specified
    #
    if params[:task_def][:group_set_id] && params[:task_def][:group_set_id] >= 0
      gs = GroupSet.find(params[:task_def][:group_set_id])
      task_def.group_set = gs if gs.unit == unit
    end

    task_def.save!

    present task_def, with: Entities::TaskDefinitionEntity, my_role: unit.role_for(current_user)
  end

  desc 'Edits the given task definition'
  params do
    requires :id, type: Integer, desc: 'The task id to edit'
    requires :task_def, type: Hash do
      optional :tutorial_stream_abbr,     type: String,   desc: 'The abbreviation of the tutorial stream'
      optional :name,                     type: String,   desc: 'The name of this task def'
      optional :description,              type: String,   desc: 'The description of this task def'
      optional :weighting,                type: Integer,  desc: 'The weighting of this task'
      optional :target_grade,             type: Integer,  desc: 'Target grade for task'
      optional :group_set_id,             type: Integer,  desc: 'Related group set'
      optional :start_date,               type: Date,     desc: 'The date when the task should be started'
      optional :target_date,              type: Date,     desc: 'The date when the task is due'
      optional :due_date,                 type: Date,     desc: 'The deadline date'
      optional :abbreviation,             type: String,   desc: 'The abbreviation of the task'
      optional :restrict_status_updates,  type: Boolean,  desc: 'Restrict updating of the status to staff'
      optional :upload_requirements,      type: String,   desc: 'Task file upload requirements'
      optional :plagiarism_warn_pct,      type: Integer,  desc: 'The percent at which to record and warn about plagiarism'
      optional :is_graded,                type: Boolean,  desc: 'Whether or not this task definition is a graded task'
      optional :max_quality_pts,          type: Integer,  desc: 'A range for quality points when quality is assessed'
      optional :assessment_enabled,       type: Boolean,  desc: 'Enable or disable assessment'
      optional :overseer_image_id,        type: Integer,  desc: 'The id of the Docker image name for overseer'
      optional :moss_language,            type: String,   desc: 'The language to use for code similarity checks'
    end
  end
  put '/units/:unit_id/task_definitions/:id' do
    unit = Unit.find(params[:unit_id])
    task_def = unit.task_definitions.find(params[:id])

    unless authorise? current_user, task_def.unit, :add_task_def
      error!({ error: 'Not authorised to create a task definition of this unit' }, 403)
    end

    task_params = ActionController::Parameters.new(params)
                                              .require(:task_def)
                                              .permit(
                                                :name,
                                                :description,
                                                :weighting,
                                                :target_grade,
                                                :start_date,
                                                :target_date,
                                                :due_date,
                                                :abbreviation,
                                                :restrict_status_updates,
                                                :plagiarism_warn_pct,
                                                :is_graded,
                                                :max_quality_pts,
                                                :assessment_enabled,
                                                :overseer_image_id,
                                                :moss_language
                                              )

    # Ensure changes to a TD defined as a 'draft task definition' are validated
    if unit.draft_task_definition_id == params[:id]
      if params[:task_def][:upload_requirements]
        requirements = JSON.parse(params[:task_def][:upload_requirements])
        if requirements.length != 1 || requirements[0]['type'] != 'document'
          error!({ error: 'Task is marked as the draft learning summary task definition. A draft learning summary task can only contain a single document upload.' }, 403)
        end
      end
    end

    task_def.update!(task_params)

    # Set the tutorial stream
    tutorial_stream_abbr = params[:task_def][:tutorial_stream_abbr]
    unless tutorial_stream_abbr.nil?
      tutorial_stream = task_def.unit.tutorial_streams.find_by!(abbreviation: tutorial_stream_abbr)
      task_def.tutorial_stream = tutorial_stream
      task_def.save!
    end

    #
    # Link in group set if specified
    #
    if params[:task_def][:group_set_id]
      if params[:task_def][:group_set_id] >= 0
        gs = GroupSet.find(params[:task_def][:group_set_id])
        if gs.unit == task_def.unit
          task_def.group_set = gs
          task_def.save!
        end
      else
        task_def.group_set = nil
        task_def.save!
      end
    end

    present task_def, with: Entities::TaskDefinitionEntity, my_role: unit.role_for(current_user)
  end

  desc 'Upload CSV of task definitions to the provided unit'
  params do
    requires :file, type: File, desc: 'CSV upload file.'
    requires :unit_id, type: Integer, desc: 'The unit to upload tasks to'
  end
  post '/csv/task_definitions' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :upload_csv
      error!({ error: 'Not authorised to upload CSV of tasks' }, 403)
    end

    if params[:file].blank?
      error!({ error: 'No file uploaded' }, 403)
    end

    path = params[:file][:tempfile].path

    # check mime is correct before uploading
    ensure_csv!(path)

    # Actually import...
    unit.import_tasks_from_csv(File.new(path))
  end

  desc 'Download CSV of all task definitions for the given unit'
  params do
    requires :unit_id, type: Integer, desc: 'The unit to download tasks from'
  end
  get '/csv/task_definitions' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :download_unit_csv
      error!({ error: 'Not authorised to download CSV of tasks' }, 403)
    end

    content_type 'application/octet-stream'
    header['Content-Disposition'] = "attachment; filename=#{unit.code}-Tasks.csv"
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'
    env['api.format'] = :binary
    unit.task_definitions_csv
  end

  desc 'Delete a task definition'
  delete '/units/:unit_id/task_definitions/:id' do
    task_def = TaskDefinition.find(params[:id])

    unless authorise? current_user, task_def.unit, :add_task_def
      error!({ error: 'Not authorised to delete a task definition of this unit' }, 403)
    end

    task_def.destroy
    task_def.destroyed?
  end

  desc 'Upload the task sheet for a given task'
  params do
    requires :unit_id, type: Integer, desc: 'The related unit'
    requires :task_def_id, type: Integer, desc: 'The related task definition'
    requires :file, type: File, desc: 'The task sheet pdf'
  end
  post '/units/:unit_id/task_definitions/:task_def_id/task_sheet' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :add_task_def
      error!({ error: 'Not authorised to upload tasks of unit' }, 403)
    end

    task_def = unit.task_definitions.find(params[:task_def_id])

    file = params[:file]

    file_result = FileHelper.accept_file(file, 'task sheet', 'document')
    unless file_result[:accepted]
      error!({ error: "'#{file[:name]}' is not an acceptable format: #{file_result[:msg]}" }, 403)
    end

    # Actually import...
    task_def.add_task_sheet(file[:tempfile].path)
    true
  end

  desc 'Test overseer assessment for a given task'
  params do
    requires :unit_id, type: Integer, desc: 'The related unit'
    requires :task_def_id, type: Integer, desc: 'The related task definition'
    optional :file0, type: Rack::Multipart::UploadedFile, desc: 'file 0.'
    optional :file1, type: Rack::Multipart::UploadedFile, desc: 'file 1.'
    # This API accepts more than 2 files, file0 and file1 are just examples.
  end
  post '/units/:unit_id/task_definitions/:task_def_id/test_overseer_assessment' do
    logger.info '********* - Starting overseer test'
    return 'Overseer is not enabled' if !Doubtfire::Application.config.overseer_enabled

    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :perform_overseer_assessment_test
      error!({ error: 'Not authorised to test overseer assessment of tasks of this unit' }, 403)
    end

    task_definition = unit.task_definitions.find(params[:task_def_id])

    project = Project.where(unit: unit, user: current_user).first

    if project.nil?
      # Create a project for the unit chair
      project = unit.enrol_student(current_user, Campus.first)
    end

    task = project.task_for_task_definition(task_definition)

    upload_reqs = task.upload_requirements

    # Copy files to be PDFed
    task.accept_submission(current_user, scoop_files(params, upload_reqs), current_user, self, nil, 'ready_for_feedback', nil, accepted_tii_eula: false)

    logger.info '********* - about to perform overseer submission'
    overseer_assessment = OverseerAssessment.create_for(task)
    if overseer_assessment.present?
      response = overseer_assessment.send_to_overseer

      if response[:error].present?
        error!({ error: response[:error] }, 403)
      end

      logger.info "Overseer assessment for task_def_id: #{task_definition.id} task_id: #{task.id} was performed"
    else
      logger.info "Overseer assessment for task_def_id: #{task_definition.id} task_id: #{task.id} was not performed"
    end

    # todo: Do we  need to return additional details here? e.g. the comment, and project?
    present task, with: Entities::TaskEntity, include_other_projects: true, update_only: true
  end

  desc 'Remove the task sheet for a given task'
  params do
    requires :unit_id, type: Integer, desc: 'The related unit'
    requires :task_def_id, type: Integer, desc: 'The related task definition'
  end
  delete '/units/:unit_id/task_definitions/:task_def_id/task_sheet' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :add_task_def
      error!({ error: 'Not authorised to remove task sheets of unit' }, 403)
    end

    task_def = unit.task_definitions.find(params[:task_def_id])

    # Actually delete...
    task_def.remove_task_sheet()
    true
  end

  desc 'Upload the task resources for a given task'
  params do
    requires :unit_id, type: Integer, desc: 'The related unit'
    requires :task_def_id, type: Integer, desc: 'The related task definition'
    requires :file, type: File, desc: 'The task resources zip'
  end
  post '/units/:unit_id/task_definitions/:task_def_id/task_resources' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :add_task_def
      error!({ error: 'Not authorised to upload tasks of unit' }, 403)
    end

    task_def = unit.task_definitions.find(params[:task_def_id])

    if params[:file].blank?
      error!({ error: 'No file uploaded' }, 403)
    end

    file_path = params[:file][:tempfile].path

    check_mime_against_list! file_path, 'zip', ['application/zip', 'multipart/x-gzip', 'multipart/x-zip', 'application/x-gzip', 'application/octet-stream']

    # Actually import...
    task_def.add_task_resources(file_path, copy: false)
    true
  end

  desc 'Remove the task resources for a given task'
  params do
    requires :unit_id, type: Integer, desc: 'The related unit'
    requires :task_def_id, type: Integer, desc: 'The related task definition'
  end
  delete '/units/:unit_id/task_definitions/:task_def_id/task_resources' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :add_task_def
      error!({ error: 'Not authorised to remove task resources of unit' }, 403)
    end

    task_def = unit.task_definitions.find(params[:task_def_id])

    # Actually remove...
    task_def.remove_task_resources
    true
  end

  desc 'Upload the task assessment resources for a given task'
  params do
    requires :unit_id, type: Integer, desc: 'The related unit'
    requires :task_def_id, type: Integer, desc: 'The related task definition'
    requires :file, type: Rack::Multipart::UploadedFile, desc: 'The task assessment resources zip'
  end
  post '/units/:unit_id/task_definitions/:task_def_id/task_assessment_resources' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :add_task_def
      error!({ error: 'Not authorised to upload task assessment resources of unit' }, 403)
    end

    task_def = unit.task_definitions.find(params[:task_def_id])

    file_path = params[:file][:tempfile].path

    check_mime_against_list! file_path, 'zip', ['application/zip', 'multipart/x-gzip', 'multipart/x-zip', 'application/x-gzip', 'application/octet-stream']

    # Actually import...
    task_def.add_task_assessment_resources(file_path)
    true
  end

  desc 'Remove the task assessment resources for a given task'
  params do
    requires :unit_id, type: Integer, desc: 'The related unit'
    requires :task_def_id, type: Integer, desc: 'The related task definition'
  end
  delete '/units/:unit_id/task_definitions/:task_def_id/task_assessment_resources' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :add_task_def
      error!({ error: 'Not authorised to remove task assessment resources of unit' }, 403)
    end

    task_def = unit.task_definitions.find(params[:task_def_id])

    # Actually remove...
    task_def.remove_task_assessment_resources
    true
  end

  desc 'Upload a zip file containing the task pdfs for a given task'
  params do
    requires :unit_id, type: Integer, desc: 'The unit to upload tasks for'
    requires :file, type: File, desc: 'batch file upload'
  end
  post '/units/:unit_id/task_definitions/task_pdfs' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :add_task_def
      error!({ error: 'Not authorised to upload tasks of unit' }, 403)
    end

    if params[:file].blank?
      error!({ error: 'No file uploaded' }, 403)
    end

    file = params[:file][:tempfile].path

    check_mime_against_list! file, 'zip', ['application/zip', 'multipart/x-gzip', 'multipart/x-zip', 'application/x-gzip', 'application/octet-stream']

    # Actually import...
    unit.import_task_files_from_zip file
  end

  desc 'Download the tasks related to a task definition'
  params do
    requires :unit_id, type: Integer, desc: 'The unit containing the task definition'
    requires :task_def_id, type: Integer, desc: "The task definition's id"
  end
  get '/units/:unit_id/task_definitions/:task_def_id/tasks' do
    unit = Unit.find(params[:unit_id])
    unless authorise? current_user, unit, :get_students
      error!({ error: 'Not authorised to access tasks for this unit' }, 403)
    end

    # Which task definition is this for
    task_def = unit.task_definitions.find(params[:task_def_id])

    # What stream does this relate to?
    stream = task_def.tutorial_stream

    subquery = unit
               .tutorial_enrolments
               .joins(:tutorial)
               .where('tutorials.tutorial_stream_id = :sid OR tutorials.tutorial_stream_id IS NULL', sid: (stream.present? ? stream.id : nil))
               .select('tutorials.tutorial_stream_id as tutorial_stream_id', 'tutorials.id as tutorial_id', 'project_id').to_sql

    result = unit.student_tasks
                 .joins(:project)
                 .joins(:task_status)
                 .joins("LEFT JOIN task_comments ON task_comments.task_id = tasks.id AND (task_comments.type IS NULL OR task_comments.type <> 'TaskStatusComment')")
                 .joins("LEFT OUTER JOIN (#{subquery}) as sq ON sq.project_id = projects.id")
                 .joins('LEFT OUTER JOIN task_similarities ON tasks.id = task_similarities.task_id')
                 .select(
                   'sq.tutorial_stream_id as tutorial_stream_id',
                   'sq.tutorial_id as tutorial_id',
                   'project_id',
                   'tasks.id as id',
                   'task_definition_id',
                   'task_statuses.id as status_id',
                   'completion_date',
                   'times_assessed',
                   'submission_date',
                   'grade',
                   'quality_pts',
                   "SUM(case when task_comments.date_extension_assessed IS NULL AND task_comments.type = 'ExtensionComment' AND NOT task_comments.id IS NULL THEN 1 ELSE 0 END) > 0 as has_extensions",
                   'SUM(case when task_similarities.flagged then 1 else 0 end) as similar_to_count'
                 )
                 .where('task_definition_id = :id', id: params[:task_def_id])
                 .group(
                   'sq.tutorial_id',
                   'sq.tutorial_stream_id',
                   'task_statuses.id',
                   'project_id',
                   'tasks.id',
                   'task_definition_id',
                   'status_id',
                   'completion_date',
                   'times_assessed',
                   'submission_date',
                   'grade',
                   'quality_pts'
                 )
                 .map do |t|
      {
        project_id: t.project_id,
        id: t.id,
        task_definition_id: t.task_definition_id,
        tutorial_id: t.tutorial_id,
        tutorial_stream_id: t.tutorial_stream_id,
        status: TaskStatus.id_to_key(t.status_id),
        completion_date: t.completion_date,
        submission_date: t.submission_date,
        times_assessed: t.times_assessed,
        similarity_flag: t.similar_to_count > 0,
        grade: t.grade,
        quality_pts: t.quality_pts,
        has_extensions: t.has_extensions
      }
    end

    present result, with: Grape::Presenters::Presenter
  end

  desc 'Download the task sheet containing the details related to performing that task'
  params do
    requires :unit_id, type: Integer, desc: 'The unit to upload tasks for'
    requires :task_def_id, type: Integer, desc: 'The task definition to get the pdf of'
    optional :as_attachment, type: Boolean, desc: 'Whether or not to download file as attachment. Default is false.'
  end
  get '/units/:unit_id/task_definitions/:task_def_id/task_pdf' do
    unit = Unit.find(params[:unit_id])
    task_def = unit.task_definitions.find(params[:task_def_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to download task details of unit' }, 403)
    end

    if task_def.has_task_sheet?
      path = task_def.task_sheet
      filename = "#{task_def.unit.code}-#{task_def.abbreviation}.pdf"
    else
      path = Rails.root.join('public/resources/FileNotFound.pdf')
      filename = 'FileNotFound.pdf'
    end

    if params[:as_attachment]
      header['Content-Disposition'] = "attachment; filename=#{filename}"
    end

    content_type 'application/pdf'
    stream_file path
  end

  desc 'Download the task resources'
  params do
    requires :unit_id, type: Integer, desc: 'The unit to upload tasks for'
    requires :task_def_id, type: Integer, desc: 'The task definition to get the pdf of'
  end
  get '/units/:unit_id/task_definitions/:task_def_id/task_resources' do
    unit = Unit.find(params[:unit_id])
    task_def = unit.task_definitions.find(params[:task_def_id])

    unless authorise? current_user, unit, :get_unit
      error!({ error: 'Not authorised to download task details of unit' }, 403)
    end

    if task_def.has_task_resources?
      path = task_def.task_resources
      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{task_def.abbreviation}-resources.zip"
    else
      path = Rails.root.join('public/resources/FileNotFound.pdf')
      content_type 'application/pdf'
      header['Content-Disposition'] = 'attachment; filename=FileNotFound.pdf'
    end

    stream_file path
  end

  desc 'Download the task assessment resources'
  params do
    requires :unit_id, type: Integer, desc: 'The unit to upload tasks for'
    requires :task_def_id, type: Integer, desc: 'The task definition to get the assessment resources of'
  end
  get '/units/:unit_id/task_definitions/:task_def_id/task_assessment_resources' do
    unit = Unit.find(params[:unit_id])
    task_def = unit.task_definitions.find(params[:task_def_id])

    unless authorise? current_user, unit, :add_task_def
      error!({ error: 'Not authorised to download task details of unit' }, 403)
    end

    if task_def.has_task_assessment_resources?
      path = task_def.task_assessment_resources
      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{task_def.abbreviation}-assessment-resources.zip"
    else
      path = Rails.root.join('public/resources/FileNotFound.pdf')
      content_type 'application/pdf'
      header['Content-Disposition'] = 'attachment; filename=FileNotFound.pdf'
    end

    stream_file path
  end
end
