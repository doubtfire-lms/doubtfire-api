require 'grape'

class TasksApi < Grape::API
  helpers AuthenticationHelpers
  helpers AuthorisationHelpers
  helpers FileStreamHelper

  before do
    authenticated?
  end

  #
  # Tasks only used for the task summary stats view...
  #
  desc "Get all the current user's tasks"
  params do
    requires :unit_id, type: Integer, desc: 'Unit to fetch the task details for'
  end
  get '/tasks' do
    unit = Unit.find(params[:unit_id])

    unless authorise? current_user, unit, :get_students
      error!({ error: 'You do not have permission to read these task details' }, 403)
    end

    result = unit.student_tasks
                 .joins(:task_status)
                 .joins('LEFT OUTER JOIN tutorial_enrolments ON tutorial_enrolments.project_id = projects.id')
                 .joins('LEFT OUTER JOIN tutorials ON tutorial_enrolments.tutorial_id = tutorials.id AND (tutorials.tutorial_stream_id = task_definitions.tutorial_stream_id OR tutorials.tutorial_stream_id IS NULL)')
                 .select(
                   'tasks.id',
                   'task_statuses.id as status_id',
                   'task_definition_id',
                   'tutorials.id AS tutorial_id',
                   'tutorials.tutorial_stream_id AS tutorial_stream_id'
                 )
                 .where('tasks.task_status_id > 1')
                 .map do |r|
      {
        id: r.id,
        task_definition_id: r.task_definition_id,
        status: TaskStatus.id_to_key(r.status_id),
        tutorial_id: r.tutorial_id,
        tutorial_stream_id: r.tutorial_stream_id
      }
    end

    present result, with: Grape::Presenters::Presenter
  end

  desc 'Refresh the most frequently changed task details for a project - allowing easy refresh of student details'
  params do
    requires :project_id, type: Integer, desc: 'The id of the project with the task, or tasks to get'
    requires :task_definition_id, type: Integer, desc: 'The id of the task definition to get, when not provided all tasks are returned'
  end
  get '/projects/:project_id/refresh_tasks/:task_definition_id' do
    project = Project.find(params[:project_id])

    unless authorise? current_user, project, :get
      error!({ error: 'You do not have permission to access this project' }, 403)
    end

    base = project.tasks

    if params[:task_definition_id].present?
      base = base.where('tasks.task_definition_id = :task_definition_id', task_definition_id: params[:task_definition_id])
    end

    result = base
             .map do |task|
      {
        task_definition_id: task.task_definition_id,
        status: TaskStatus.id_to_key(task.task_status_id),
        due_date: task.due_date,
        extensions: task.extensions
      }
    end

    if params[:task_definition_id].present?
      result = result.first
    end

    present result, with: Grape::Presenters::Presenter
  end

  desc 'Pin a task to the user\'s task inbox'
  params do
    requires :id, type: Integer, desc: 'The ID of the task to be pinned'
  end
  post '/tasks/:id/pin' do
    task = Task.find(params[:id])

    unless authorise? current_user, task.unit, :provide_feedback
      error!({ error: 'Not authorised to pin task' }, 403)
    end

    TaskPin.find_or_create_by(task: task, user: current_user)

    present true, Grape::Presenters::Presenter
  end

  desc 'Unpin a task from the user\'s task inbox'
  params do
    requires :id, type: Integer, desc: 'The ID of the task to be unpinned'
  end
  delete '/tasks/:id/pin' do
    TaskPin.find_by!(user: current_user, task_id: params[:id]).destroy
    present true, Grape::Presenters::Presenter
  end

  desc 'Update a task using its related project and task definition'
  params do
    # requires :id, type: Integer, desc: 'The project id to locate'
    # requires :task_definition_id, type: Integer, desc: 'The id of the task definition of the task to update in this project'
    optional :trigger, type: String, desc: 'New status'
    optional :include_in_portfolio, type: Boolean, desc: 'Indicate if this task should be in the portfolio'
    optional :grade, type: Integer, desc: 'Grade value if task is a graded task (required if task definition is a graded task)'
    optional :quality_pts, type: Integer, desc: 'Quality points value if task has quality assessment'
  end
  put '/projects/:id/task_def_id/:task_definition_id' do
    project = Project.find(params[:id])
    grade = params[:grade]
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])
    needs_upload_docs = !task_definition.upload_requirements.empty?

    # check the user can put this task
    if authorise? current_user, project, :make_submission
      task = project.task_for_task_definition(task_definition)

      # if trigger supplied...
      unless params[:trigger].nil?
        # Check if they should be using portfolio_evidence api
        if needs_upload_docs && params[:trigger] == 'ready_for_feedback'
          error!({ error: 'Cannot set this task status to ready to mark without uploading documents.' }, 403)
        end

        if task.group_task? && !task.group
          error!({ error: "This task requires a group. Ensure you are in a group for the unit's #{task.task_definition.group_set.name}" }, 403)
        end

        logger.info "#{current_user.username} assessing task #{task.id} to #{params[:trigger]}"
        result = task.trigger_transition(trigger: params[:trigger], by_user: current_user, quality: params[:quality_pts])
        if result.nil? && task.task_definition.restrict_status_updates
          error!({ error: 'This task can only be updated by your tutor.' }, 403)
        end
      end

      # if grade was supplied
      unless grade.nil?
        # try to grade the task
        task.grade_task grade, self
      end

      # if include in portfolio supplied
      unless params[:include_in_portfolio].nil?
        task.include_in_portfolio = params[:include_in_portfolio]
        task.save
      end

      present task, with: Entities::TaskEntity, include_other_projects: true, update_only: true
    else
      error!({ error: "Couldn't find Task with id=#{params[:id]}" }, 403)
    end
  end

  desc 'Get the submission details of a task, indicating if it has a pdf to view'
  params do
    requires :id, type: Integer, desc: 'The project id to locate'
    requires :task_definition_id, type: Integer, desc: 'The id of the task definition of the task to update in this project'
  end
  get '/projects/:id/task_def_id/:task_definition_id/submission_details' do
    # Get the project and task_definition based on uploaded details.
    project = Project.find(params[:id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])

    # check the user can put this task
    error!(error: 'You do not have permission to read submissions for this project.') unless authorise? current_user, project, :get_submission

    # ensure there can be a pdf...
    needs_upload_docs = !task_definition.upload_requirements.empty?

    # check if we actually have this task... if not must be false.
    if needs_upload_docs && project.has_task_for_task_definition?(task_definition)
      task = project.task_for_task_definition(task_definition)

      # return the details as json
      result = {
        has_pdf: task.has_pdf,
        submission_date: task.submission_date,
        processing_pdf: task.processing_pdf?
      }
    else
      result = {
        has_pdf: false,
        processing_pdf: false
      }
    end

    present result, with: Grape::Presenters::Presenter
  end

  desc 'Get the files associated with a submission'
  params do
    requires :id, type: Integer, desc: 'The project id to locate'
    requires :task_definition_id, type: Integer, desc: 'The id of the task definition of the task to get the files from'
  end
  get '/projects/:id/task_def_id/:task_definition_id/submission_files' do
    # Get the project and task_definition based on uploaded details.
    project = Project.find(params[:id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])

    # check the user can put this task
    error!(error: 'You do not have permission to read submissions for this project.') unless authorise? current_user, project, :get_submission

    # Get the actual task...
    task = project.task_for_task_definition(task_definition)

    # Find the file
    file_loc = FileHelper.zip_file_path_for_done_task(task)

    if file_loc.nil? || !File.exist?(file_loc)
      file_loc = Rails.root.join('public', 'resources', 'FileNotFound.pdf')
      header['Content-Disposition'] = 'attachment; filename=FileNotFound.pdf'
    else
      header['Content-Disposition'] = "attachment; filename=#{project.student.username}-#{task.task_definition.abbreviation}.zip"
    end
    header['Access-Control-Expose-Headers'] = 'Content-Disposition'

    # Set download headers...
    content_type 'application/octet-stream'

    # Return the file data
    stream_file file_loc
  end
end
