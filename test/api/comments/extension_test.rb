require 'test_helper'

class ExtensionTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_extension_application
    project = Project.first
    user = project.student
    unit = project.unit

    td = TaskDefinition.new({
        unit_id: unit.id,
        name: 'status task change',
        description: 'status task change test',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 1.day,
        abbreviation: 'LESS1WEEKEXTTEST',
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!

    data_to_post = {
      weeks_requested: '1',
      comment: "I need a lot of help"
    }

    # Request a 2 day extension
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 1, "Error: Deadline less than a week, requested weeks should be 1, found #{response["weeks_requested"]}."

    # Request a 2 week extension on the day
    td.due_date = Time.zone.now + 2.weeks
    td.save!
    data_to_post["weeks_requested"] = '2'

    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 2, "Error: Weeks requested weeks should be 2, found #{response["weeks_requested"]}."

    # Ask for too long an extension
    data_to_post["weeks_requested"] = '5'
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 403, last_response.status, "Error: Allowed too long of a request to be applied."

    # Ask for 0 week extension
    data_to_post["weeks_requested"] = '0'
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 403, last_response.status, "Error: Should not allow 0 week extension requests"


    td.destroy!
  end

  # Test that extension requests are not read by main tutor until they are assessed
  def test_extension_application
    project = Project.first
    user = project.student
    unit = project.unit
    main_tutor = project.main_tutor
    other_tutor = unit.main_convenor

    td = TaskDefinition.new({
        unit_id: unit.id,
        name: 'status task change',
        description: 'status task change test',
        weighting: 4,
        target_grade: 0,
        start_date: Time.zone.now - 2.weeks,
        target_date: Time.zone.now - 1.day,
        due_date: Time.zone.now + 1.day,
        abbreviation: 'LESS1WEEKEXTTEST',
        restrict_status_updates: false,
        upload_requirements: [ ],
        plagiarism_warn_pct: 0.8,
        is_graded: false,
        max_quality_pts: 0
      })
    td.save!
    data_to_post = {
      weeks_requested: '1',
      comment: "I need a lot of help"
    }

    # Request a 2 day extension
    post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
    response = last_response_body
    assert_equal 201, last_response.status
    assert response["weeks_requested"] == 1, "Error: Deadline less than a week, requested weeks should be 1, found #{response["weeks_requested"]}."

    tc = TaskComment.find(response['id'])

    # Check it is not read by the main tutor
    refute tc.read_by?(main_tutor), "Error: Should not be read by main tutor on create"
    assert tc.read_by?(user), "Error: Should be read by student on create"

    # Check that reading by main tutor does not read the task
    tc.read_by? main_tutor
    refute tc.read_by?(main_tutor), "Error: Should not be read by main tutor even when they read it"

    # Check it is read after grant by another user
    tc.assess_extension other_tutor, true
    assert tc.read_by?(main_tutor), "Error: Should be read by main tutor after assess"

#Check if the student is  eligible for extension
	# test assess extension
    data_to_post = {
      granted: true
    }

	put with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/assess_extension/#{tc.id}", main_tutor), data_to_post
	response = last_response_body
	assert_equal 403, last_response.status
	assert_equal "Extension has already been assessed", last_response_body["error"]

	put with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/assess_extension/#{tc.id}", user), data_to_post
	response = last_response_body
	assert_equal 403, last_response.status
	assert_equal "Not authorised to assess an extension for this task", last_response_body["error"]

    td.destroy!
  end

#Check if there is any negative extension
	def test_negative_extension
		project = Project.first
		user = project.student
		unit = project.unit

		td = TaskDefinition.new({
		    unit_id: unit.id,
		    name: 'status task change',
		    description: 'status task change test',
		    weighting: 4,
		    target_grade: 0,
		    start_date: Time.zone.now - 2.weeks,
		    target_date: Time.zone.now - 1.day,
		    due_date: Time.zone.now + 1.day,
		    abbreviation: 'LESS1WEEKEXTTEST',
		    restrict_status_updates: false,
		    upload_requirements: [ ],
		    plagiarism_warn_pct: 0.8,
		    is_graded: false,
		    max_quality_pts: 0
		  })
		td.save!

		data_to_post = {
		  weeks_requested: '-1',
		  comment: "too long to submit the task"
		}

		# Request a negative extension
		post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
		response = last_response_body
		assert_equal 403, last_response.status, "Error: Extension request cannot be negative"

		td.destroy!
	end

	# testing to extend after the submission due date
	def test_extension_after_due_date
		project = Project.first
		user = project.student
		unit = project.unit

		# the task definition to new submission date
		td = TaskDefinition.new({
		    unit_id: unit.id,
		    name: 'status task change',
		    description: 'status task change test',
		    weighting: 4,
		    target_grade: 0,
		    start_date: Time.zone.now - 2.weeks,
		    target_date: Time.zone.now,
		    due_date: Time.zone.now - 1.day,
		    abbreviation: 'TESTEXTAFTERDUEDATE',
		    restrict_status_updates: false,
		    upload_requirements: [ ],
		    plagiarism_warn_pct: 0.8,
		    is_graded: false,
		    max_quality_pts: 0
		  })
		td.save!

		data_to_post = {
		  weeks_requested: '1',
		  comment: "sorry for late request"
		}

		# Request for extension after due date
		post_json with_auth_token("/api/projects/#{project.id}/task_def_id/#{td.id}/request_extension", user), data_to_post
		response = last_response_body
		assert_equal 403, last_response.status, "Error: extension not allowed after due date"
		assert_equal "Extensions cannot be granted beyond task deadline.", last_response_body["error"]

		td.destroy!
	  end

end
