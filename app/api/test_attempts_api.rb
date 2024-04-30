require 'grape'

class TestAttemptsApi < Grape::API
  format :json

  # Enforce authentication
  before do
    authenticated?
  end

  # Assigning AuthenticationHelpers
  helpers AuthenticationHelpers

  # Handle common exceptions
  rescue_from :all do |e|
    error!({ error: e.message }, 500)
  end

  # Specific exception handler for record not found
  rescue_from ActiveRecord::RecordNotFound do |e|
    error!({ error: e.message }, 404)
  end

  # Handling validation errors from Grape
  rescue_from Grape::Exceptions::ValidationErrors do |e|
    error!({ errors: e.full_messages }, 400)
  end

  # Define the TestAttemptEntity
  class TestAttemptEntity < Grape::Entity
    expose :id, :name, :attempt_number, :pass_status, :exam_data, :completed, :cmi_entry
    expose :task_id, as: :associated_task_id
    expose :exam_result, :attempted_at
  end

  # Fetch all test results
  desc 'Get all test results'
  get '/test_attempts' do
    tests = TestAttempt.order(id: :desc)
    present tests, with: TestAttemptEntity
  end

  # Get latest test or create a new one based on completion status
  desc 'Get latest test attempt for a specific task or create a new one based on completion status'
  params do
    requires :task_id, type: Integer, desc: 'Task ID to fetch test attempts for'
  end
  get '/test_attempts/latest' do
    # Ensure task exists
    task = Task.find(params[:task_id])
    if task.nil?
      error!({ message: 'Task ID is invalid' }, 404)
      return
    else
      test_attempts = TestAttempt.find_by(task_id: :task_id)
    end

    # Take the latest test attempt if there are any for this task
    unless test_attempts.nil?
      test = test_attempts.order(id: :desc).first
    end

    if test.nil?
      test = TestAttempt.create!(
        name: "Default Test",
        attempt_number: 1,
        pass_status: false,
        exam_data: nil,
        completed: false,
        cmi_entry: 'ab-initio',
        task_id: params[:task_id]
      )
    elsif test.completed
      test = TestAttempt.create!(
        name: "Default Test",
        attempt_number: test.attempt_number + 1,
        pass_status: false,
        exam_data: nil,
        completed: false,
        cmi_entry: 'ab-initio',
        task_id: params[:task_id]
      )
    else
      test.update!(cmi_entry: 'resume')
    end

    present test, with: TestAttemptEntity
  end

  # Fetch the latest completed test result
  desc 'Get the latest completed test result'
  params do
    requires :task_id, type: Integer, desc: 'Task ID to fetch completed test attempt for'
  end
  get '/test_attempts/completed-latest' do
    # Ensure task exists
    task = Task.find(params[:task_id])
    if task.nil?
      error!({ message: 'Task ID is invalid' }, 404)
      return
    else
      test_attempts = TestAttempt.find_by(task_id: :task_id)
    end

    # Take the latest completed test attempt if there are any for this task
    unless test_attempts.nil?
      test = test_attempts.where(completed: true).order(id: :desc).first
    end

    if test.nil?
      error!({ message: 'No completed tests found for this task' }, 404)
    else
      present test, with: TestAttemptEntity
    end
  end

  # Fetch a specific test result by ID
  desc 'Get a specific test result'
  params do
    requires :id, type: String, desc: 'ID of the test'
  end
  get '/test_attempts/:id' do
    present TestAttempt.find(params[:id]), with: TestAttemptEntity
  end

  # Create a new test result entry
  desc 'Create a new test result'
  params do
    requires :task_id, type: Integer, desc: 'ID of the associated task'
    requires :name, type: String, desc: 'Name of the test'
    requires :attempt_number, type: Integer, desc: 'Number of attempts'
    requires :pass_status, type: Boolean, desc: 'Passing status'
    optional :exam_data, type: String, desc: 'Data related to the exam'
    requires :completed, type: Boolean, desc: 'Completion status'
    optional :cmi_entry, type: String, desc: 'CMI Entry', default: "ab-initio"
    optional :exam_result, type: String, desc: 'Result of the exam'
    optional :attempted_at, type: DateTime, desc: 'Timestamp of the test attempt'
  end
  post '/test_attempts' do
    test = TestAttempt.create!(declared(params))
    present test, with: TestAttemptEntity
  end

  # Update the details of a specific test result
  desc 'Update a test result'
  params do
    optional :name, type: String, desc: 'Name of the test'
    optional :attempt_number, type: Integer, desc: 'Number of attempts'
    optional :pass_status, type: Boolean, desc: 'Passing status'
    optional :exam_data, type: String, desc: 'Data related to the exam'
    optional :completed, type: Boolean, desc: 'Completion status'
    optional :exam_result, type: String, desc: 'Exam score'
    optional :cmi_entry, type: String, desc: 'CMI Entry'
    optional :task_id, type: Integer, desc: 'ID of the associated task'
  end
  put '/test_attempts/:id' do
    test = TestAttempt.find(params[:id])
    test.update!(declared(params, include_missing: false))
    present test, with: TestAttemptEntity
  end

  # Delete a specific test result by ID
  desc 'Delete a test result'
  params do
    requires :id, type: String, desc: 'ID of the test'
  end
  delete '/test_attempts/:id' do
    TestAttempt.find(params[:id]).destroy!
  end

  # Update the exam_data of a specific test result
  desc 'Update exam data for a test result'
  params do
    requires :id, type: String, desc: 'ID of the test'
  end
  put '/test_attempts/:id/exam_data' do
    test = TestAttempt.find_by(id: params[:id])

    error!('Test not found', 404) unless test

    # Treat the entire params as the data to be saved
    exam_data = params.to_json

    begin
      JSON.parse(exam_data)
      test.update!(exam_data: exam_data)
      { message: 'Exam data updated successfully', test: test }
    rescue JSON::ParserError
      error!('Invalid JSON provided', 400)
    rescue StandardError => e
      error!(e.message, 500)
    end
  end

end
