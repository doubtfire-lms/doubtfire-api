require 'grape'

class TestAttemptsApi < Grape::API
  format :json

  helpers AuthenticationHelpers
  helpers AuthorisationHelpers

  before do
    authenticated?
  end

  # Handle common exceptions
  rescue_from :all do |e|
    error!({ error: e.message }, 500)
  end

  rescue_from ActiveRecord::RecordNotFound do |e|
    error!({ error: e.message }, 404)
  end

  rescue_from Grape::Exceptions::ValidationErrors do |e|
    error!({ errors: e.full_messages }, 400)
  end

  desc 'Get all test results for a task'
  params do
    requires :project_id, type: Integer, desc: 'The id of the project with the task'
    requires :task_definition_id, type: Integer, desc: 'The id of the task definition related to the task'
  end
  get '/projects/:project_id/task_def_id/:task_definition_id/test_attempts' do
    project = Project.find(params[:project_id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])

    unless authorise? current_user, project, :get_submission
      error!({ error: "Not authorized to get scorm attempts for task" }, 403)
    end

    task = project.task_for_task_definition(task_definition)

    attempts = TestAttempt.where("task_id = ?", task.id)
    tests = attempts.order(id: :desc)
    present tests, with: Entities::TestAttemptEntity
  end

  desc 'Get the latest test result'
  params do
    requires :project_id, type: Integer, desc: 'The id of the project with the task'
    requires :task_definition_id, type: Integer, desc: 'The id of the task definition related to the task'
    optional :completed, type: Boolean, desc: 'Get the latest completed test?'
  end
  get '/projects/:project_id/task_def_id/:task_definition_id/test_attempts/latest' do
    project = Project.find(params[:project_id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])

    unless authorise? current_user, project, :get_submission
      error!({ error: "Not authorized to get latest scorm attempt for task" }, 403)
    end

    task = project.task_for_task_definition(task_definition)

    attempts = TestAttempt.where("task_id = ?", task.id)

    test = if params[:completed]
             attempts.where(completion_status: true).order(id: :desc).first
           else
             attempts.order(id: :desc).first
           end

    if test.nil?
      error!({ message: 'No tests found for this task' }, 404)
    else
      present test, with: Entities::TestAttemptEntity
    end
  end

  desc 'Review a completed attempt'
  params do
    requires :id, type: Integer, desc: 'Test attempt ID to review'
  end
  get 'test_attempts/:id/review' do
    test = TestAttempt.find(params[:id])

    key = if current_user == test.student
            :review_own_attempt
          else
            :review_other_attempt
          end

    unless authorise? current_user, test, key, ->(role, perm_hash, other) { test.specific_permission_hash(role, perm_hash, other) }
      error!({ error: 'Not authorised to review this scorm attempt' }, 403)
    end

    if test.nil?
      error!({ message: 'Test attempt ID is invalid' }, 404)
      return
    else
      logger.debug "Request to review test attempt #{params[:id]}"
      test.review
    end
    present test, with: Entities::TestAttemptEntity
  end

  desc 'Initiate a new test attempt'
  params do
    requires :project_id, type: Integer, desc: 'The id of the project with the task'
    requires :task_definition_id, type: Integer, desc: 'The id of the task definition related to the task'
  end
  post '/projects/:project_id/task_def_id/:task_definition_id/test_attempts' do
    project = Project.find(params[:project_id])
    task_definition = project.unit.task_definitions.find(params[:task_definition_id])
    task = project.task_for_task_definition(task_definition)

    # check permissions using specific permission has with addition of make scorm attempt if scorm is enabled in task def
    unless authorise? current_user, task, :make_scorm_attempt, ->(role, perm_hash, other) { task.specific_permission_hash(role, perm_hash, other) }
      error!({ error: 'Not authorised to make a scorm attempt for this task' }, 403)
    end

    attempts = TestAttempt.where("task_id = ?", task.id)
    test_count = attempts.count

    # check if last attempt is complete
    last_attempt = attempts.order(id: :desc).first
    if test_count > 0 && last_attempt.terminated == false
      error!({ message: 'An attempt is still ongoing. Cannot initiate new attempt.' }, 400)
      return
    end

    # check if last attempt is a pass
    if test_count > 0 && last_attempt.success_status == true
      error!({ message: 'User has passed the SCORM test. Cannot initiate more attempts.' }, 400)
      return
    end

    # check attempt limit
    limit = task.task_definition.scorm_attempt_limit + task.scorm_extensions
    if limit != 0 && test_count == limit
      error!({ message: 'Attempt limit has been reached' }, 400)
      return
    end

    test = TestAttempt.create!({ task_id: task.id })
    present test, with: Entities::TestAttemptEntity
  end

  desc 'Update an existing attempt'
  params do
    requires :id, type: String, desc: 'ID of the test attempt'
    optional :cmi_datamodel, type: String, desc: 'JSON CMI datamodel to update'
    optional :terminated, type: Boolean, desc: 'Terminate the current attempt'
    optional :success_status, type: Boolean, desc: 'Override the success status of the current attempt'
  end
  patch 'test_attempts/:id' do
    test = TestAttempt.find(params[:id])

    if params[:success_status].present?
      unless authorise? current_user, test, :override_success_status
        error!({ error: 'Not authorised to override the success status of this scorm attempt' }, 403)
      end

      test.override_success_status(params[:success_status])
    else
      unless authorise? current_user, test, :update_attempt
        error!({ error: 'Not authorised to update this scorm attempt' }, 403)
      end

      attempt_data = ActionController::Parameters.new(params).permit(:cmi_datamodel, :terminated)

      unless test.terminated
        test.update!(attempt_data)
        test.save!
        if params[:terminated]
          test.add_scorm_comment
        end
      end
    end

    present test, with: Entities::TestAttemptEntity
  end

  desc 'Delete a test attempt'
  params do
    requires :id, type: String, desc: 'ID of the test attempt'
  end
  delete 'test_attempts/:id' do
    test = TestAttempt.find(params[:id])

    unless authorise? current_user, test, :delete_attempt
      error!({ error: 'Not authorised to delete this scorm attempt' }, 403)
    end

    test.destroy!
  end
end
