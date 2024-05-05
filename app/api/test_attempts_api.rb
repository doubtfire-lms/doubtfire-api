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
    # Fetch all test results, ordered by ID in descending order
    desc 'Get all test results'
    get do
      tests = TestAttempt.order(id: :desc)
      present :data, tests, with: Entities::TestAttemptEntity
    end

    # Get latest test or create a new one based on completion status
    desc 'Get latest test attempt for a specific task or create a new one based on completion status'
    params do
      requires :task_id, type: Integer, desc: 'Task ID to fetch test attempts for'
    end
    get 'latest' do
      # Ensure task exists
      task = Task.find(params[:task_id])
      if task.nil?
        error!({ message: 'Task ID is invalid' }, 404)
        return
      else
        test_attempts = TestAttempt.where("task_id = ?", params[:task_id])
      end

      test = test_attempts.order(id: :desc).first

      if test.nil?
        test = TestAttempt.create!(
          name: "First Test",
          attempt_number: 1,
          pass_status: false,
          suspend_data: nil,
          completed: false,
          cmi_entry: 'ab-initio',
          attempted_at: DateTime.now,
          task_id: params[:task_id]
        )
      elsif test.completed
        test = TestAttempt.create!(
          name: "New Attempt",
          attempt_number: test.attempt_number + 1,
          pass_status: false,
          suspend_data: nil,
          completed: false,
          cmi_entry: 'ab-initio',
          attempted_at: DateTime.now,
          task_id: params[:task_id]
        )
      else
        test.update!(cmi_entry: 'resume')
      end

      present :data, test, with: Entities::TestAttemptEntity
    end

    # Fetch the latest completed test result
    desc 'Get the latest completed test result'
    params do
      requires :task_id, type: Integer, desc: 'Task ID to fetch completed test attempt for'
    end
    get 'completed-latest' do
      # Ensure task exists
      task = Task.find(params[:task_id])
      if task.nil?
        error!({ message: 'Task ID is invalid' }, 404)
        return
      else
        test_attempts = TestAttempt.where("task_id = ?", params[:task_id])
      end

      test = test_attempts.where(completed: true).order(id: :desc).first

      if test.nil?
        error!({ message: 'No completed tests found for this task' }, 404)
      else
        present :data, test, with: Entities::TestAttemptEntity
      end
    end

    # Fetch a specific test result by ID
    desc 'Get a specific test result'
    params do
      requires :id, type: String, desc: 'ID of the test'
    end
    get ':id' do
      present TestAttempt.find(params[:id]), with: Entities::TestAttemptEntity
    end

    # Create a new test result entry
    desc 'Create a new test result'
    params do
      requires :name, type: String, desc: 'Name of the test'
      requires :attempt_number, type: Integer, desc: 'Number of attempts'
      requires :pass_status, type: Boolean, desc: 'Passing status'
      requires :suspend_data, type: String, desc: 'Suspended data in JSON'
      requires :completed, type: Boolean, desc: 'Completion status'
      optional :cmi_entry, type: String, desc: 'CMI Entry', default: "ab-initio"
      optional :exam_result, type: String, desc: 'Result of the exam'
      optional :attempted_at, type: DateTime, desc: 'Timestamp of the test attempt'
      requires :task_id, type: Integer, desc: 'ID of the associated task'
    end
    post do
      test = TestAttempt.create!(params)
      present :data, test, with: Entities::TestAttemptEntity
    end

    # Update the details of a specific test result
    desc 'Update a test result'
    params do
      requires :id, type: String, desc: 'ID of the test'
      optional :name, type: String, desc: 'Name of the test'
      optional :attempt_number, type: Integer, desc: 'Number of attempts'
      optional :pass_status, type: Boolean, desc: 'Passing status'
      optional :suspend_data, type: String, desc: 'Suspended data in JSON'
      optional :completed, type: Boolean, desc: 'Completion status'
      optional :exam_result, type: String, desc: 'Exam score'
      optional :cmi_entry, type: String, desc: 'CMI Entry'
      optional :attempted_at, type: DateTime, desc: 'Timestamp of the test attempt'
    end
    put ':id' do
      TestAttempt.find(params[:id]).update!(params.except(:id))
    end

    # Delete a specific test result by ID
    desc 'Delete a test result'
    params do
      requires :id, type: String, desc: 'ID of the test'
    end
    delete ':id' do
      TestAttempt.find(params[:id]).destroy!
    end

    # Update the suspend_data of a specific test result
    desc 'Update suspend data for a test result'
    params do
      requires :id, type: String, desc: 'ID of the test'
      requires :suspend_data, type: Hash, desc: 'Suspend data to be saved'
    end
    put ':id/suspend' do
      test = TestAttempt.find_by(id: params[:id])

      error!('Test not found', 404) unless test

      suspend_data = params[:suspend_data].to_json

      begin
        JSON.parse(suspend_data)
        test.update!(suspend_data: suspend_data)
        { message: 'Suspend data updated successfully', test: test }
      rescue JSON::ParserError
        error!('Invalid JSON provided', 400)
      rescue => e
        error!(e.message, 500)
      end
    end
  end
end
