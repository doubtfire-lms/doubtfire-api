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

  resources :test_attempts do
    desc 'Get all test results for a task'
    params do
      requires :task_id, type: Integer, desc: 'Task ID to fetch test attempts for'
    end
    get ':task_id' do
      task = Task.find(params[:task_id])
      if task.nil?
        error!({ message: 'Task ID is invalid' }, 404)
        return
      else
        attempts = TestAttempt.where("task_id = ?", params[:task_id])
      end
      tests = attempts.order(id: :desc)
      present tests, with: Entities::TestAttemptEntity
    end

    desc 'Get the latest test result'
    params do
      requires :task_id, type: Integer, desc: 'Task ID to fetch the latest test attempt for'
      optional :completed, type: Boolean, desc: 'Get the latest completed test?'
    end
    get ':task_id/latest' do
      # Ensure task exists
      task = Task.find(params[:task_id])
      if task.nil?
        error!({ message: 'Task ID is invalid' }, 404)
        return
      else
        attempts = TestAttempt.where("task_id = ?", params[:task_id])
      end

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

    desc 'Review a completed session'
    params do
      requires :task_id, type: Integer, desc: 'Task ID to fetch the latest test attempt for'
      requires :session_id, type: Integer, desc: 'Test attempt ID to review'
    end
    get ':task_id/review/:session_id' do
      session = TestAttempt.find(params[:session_id])
      if session.nil?
        error!({ message: 'Session ID is invalid' }, 404)
        return
      else
        logger.debug "Request to review test session #{params[:session_id]}"
        session.review
        # TODO: add review permission flag to taskdef
      end
      present test, with: Entities::TestAttemptEntity
    end

    desc 'Initiate a new test session'
    params do
      requires :task_id, type: Integer, desc: 'ID of the associated task'
    end
    post ':task_id/session' do
      task = Task.find(params[:task_id])
      if task.nil?
        error!({ message: 'Task ID is invalid' }, 404)
        return
      else
        attempts = TestAttempt.where("task_id = ?", params[:task_id])
      end

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

    desc 'Update an existing session'
    params do
      requires :task_id, type: Integer, desc: 'ID of the associated task'
      requires :id, type: String, desc: 'ID of the test attempt'
      optional :cmi_datamodel, type: String, desc: 'JSON CMI datamodel to update'
      optional :terminated, type: Boolean, desc: 'Terminate the current session'
    end
    patch ':task_id/session/:id' do
      session_data = ActionController::Parameters.new(params).permit(:cmi_datamodel, :terminated)
      test = TestAttempt.find(params[:id])

      unless test.terminated
        test.update!(session_data)
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
      requires :task_id, type: Integer, desc: 'ID of the associated task'
      requires :id, type: String, desc: 'ID of the test attempt'
    end
    delete ':task_id/:id' do
      raise NotImplementedError
      # TODO: fix permissions before enabling this

      # test = TestAttempt.find(params[:id])
      # test.destroy!
    end
  end
end
