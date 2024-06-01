require 'grape'

class TestAttemptsApi < Grape::API
  format :json

  helpers AuthenticationHelpers

  # before do
  #   authenticated?
  # end

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
    attempt = TestAttempt.find(params[:id])
    if attempt.nil?
      error!({ message: 'Test attempt ID is invalid' }, 404)
      return
    else
      logger.debug "Request to review test attempt #{params[:id]}"
      attempt.review
      # TODO: add review permission flag to taskdef
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

    attempts = TestAttempt.where("task_id = ?", task.id)

    # check attempt limit
    test_count = attempts.count
    limit = task.task_definition.scorm_attempt_limit
    if test_count > limit && limit != 0
      error!({ message: 'Attempt limit has been reached' }, 400)
      return
    end

    metadata = params.merge(attempt_number: test_count + 1)
    test = TestAttempt.create!(metadata)
    present test, with: Entities::TestAttemptEntity
  end

  desc 'Update an existing attempt'
  params do
    requires :id, type: String, desc: 'ID of the test attempt'
    optional :cmi_datamodel, type: String, desc: 'JSON CMI datamodel to update'
    optional :terminated, type: Boolean, desc: 'Terminate the current attempt'
  end
  patch 'test_attempts/:id' do
    attempt_data = ActionController::Parameters.new(params).permit(:cmi_datamodel, :terminated)
    test = TestAttempt.find(params[:id])

    unless test.terminated
      test.update!(attempt_data)
      test.save!
      if params[:terminated]
        task = Task.find(test.task_id)
        task.add_scorm_comment(test)
      end
    end
    present test, with: Entities::TestAttemptEntity
  end

  desc 'Delete a test attempt'
  params do
    requires :id, type: String, desc: 'ID of the test attempt'
  end
  delete 'test_attempts/:id' do
    raise NotImplementedError
    # TODO: fix permissions before enabling this

    # test = TestAttempt.find(params[:id])
    # test.destroy!
  end
end
