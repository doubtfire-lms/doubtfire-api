require 'test_helper'
require 'securerandom'
require 'json'

class LtiApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def test_ensure_jwt_secret_is_valid
    # Simply validate that our ENV var is not nil
    secret_key = Doubtfire::Application.config.lti_api_secret
    assert_not_nil secret_key, "Lti API Secret is not set"
  end

  def test_invalid_jwt
    urls = [
      "/api/auth/lti",
      "/api/lti/link",
      "/api/lti/enrol",
      "/api/lti/enrol/bulk",
      "/api/lti/grades"
    ]

    # Test tokens without jti or expiration
    token_missing_exp = {
      jti: SecureRandom.uuid
    }
    token_missing_jti = {
      exp: Time.now.to_i + 30
    }

    # Test an expired token
    token_expired = {
      exp: Time.now.to_i - 30,
      jti: SecureRandom.uuid
    }

    payloads = [
      token_missing_exp,
      token_missing_jti,
      token_expired
    ]

    secret_key = Doubtfire::Application.config.lti_api_secret

    tokens = []
    payloads.each do |payload|
      token = JWT.encode(payload, secret_key, 'HS256')
      tokens.push(token)

      # Test invalid signatures
      token_wrong_sig = JWT.encode(payload, 'wrong-secret-key', 'HS256')
      tokens.push(token_wrong_sig)
    end

    add_auth_header_for(user: FactoryBot.create(:user, :convenor))

    urls.each do |url|
      tokens.each do |token|
        data = {
          ltik: token
        }
        post url, data
        assert_equal 403, last_response.status, "Expected 'Invalid LTI token. #{url} -  #{last_response_body}"
        assert_equal "Invalid LTI token.", last_response_body['error'], "Expected 'Invalid LTI token.' #{url} - #{last_response_body}"
      end
    end
  end

  def test_invalid_unit
    secret_key = Doubtfire::Application.config.lti_api_secret

    routes_expecting_unit = [
      "/api/lti/link",
      "/api/lti/enrol",
      "/api/lti/enrol/bulk",
      "/api/lti/grades"
    ]

    payload_missing_unit_id = {
      exp: Time.now.to_i + 30,
      jti: SecureRandom.uuid
    }
    token_missing_unit_id = JWT.encode(payload_missing_unit_id, secret_key, 'HS256')

    add_auth_header_for(user: FactoryBot.create(:user, :convenor))

    # Ensure we get a 401 error if unit_id is missing from the token
    routes_expecting_unit.each do |url|
      post url, { ltik: token_missing_unit_id }
      assert_equal 400, last_response.status, "Expected 400 from #{url} with missing unit_id #{last_response_body}"
      assert_equal "Invalid LTI token.", last_response_body['error']
    end

    # Ensure we get a 404 if the unit (id) does not exist
    payload_invalid_unit_id = {
      unit_id: 9_999_999, # Unit should not exist
      exp: Time.now.to_i + 30,
      jti: SecureRandom.uuid
    }
    token_invalid_unit_id = JWT.encode(payload_invalid_unit_id, secret_key, 'HS256')

    routes_expecting_unit.each do |url|
      post url, { ltik: token_invalid_unit_id }
      assert_equal 404, last_response.status, "Expected 404 from #{url} with invalid unit #{last_response_body}"
      assert_equal "Unit does not exist.", last_response_body['error']
    end
  end

  def test_lti_authentication
    secret_key = Doubtfire::Application.config.lti_api_secret

    username = 'user12345'
    member = {
      user_id: '3',
      name: 'Nickname 2',
      given_name: 'First name 2',
      family_name: 'Last name 2',
      email: "#{username}@doubtfire.com",
      ext_user_username: 'student_test_lti3',
      roles: ['Learner']
    }
    token = JWT.encode({
                         member: member,
                         exp: Time.now.to_i + 30,
                         jti: SecureRandom.uuid
                       }, secret_key, 'HS256')

    #  Retrieve the temporary auth token and username
    post '/api/auth/lti', { ltik: token }
    assert_equal 201, last_response.status
    assert last_response_body.key?('username')
    assert last_response_body.key?('auth_token')
    assert_equal username, last_response_body['username']

    # Sign in with the one-time auth token and username
    post '/api/auth', { username: last_response_body['username'], auth_token: last_response_body['auth_token'] }
    assert_equal 201, last_response.status
    assert last_response_body.key?('user')
    user_body = last_response_body['user']
    assert user_body.key?('id')
    user_id = user_body['id']

    # Ensure user was created
    user = User.find(user_id)
    assert user.valid?

    assert_equal member[:ext_user_username], user.login_id
    assert_equal member[:given_name], user.first_name
    assert_equal member[:family_name], user.last_name
    assert_equal member[:name], user.nickname
    assert_equal member[:email], user.email
    assert_equal username, user.username
  end

  def test_convenor_can_link_requested_unit
    # Create convenor
    convenor = FactoryBot.create(:user, :convenor)

    # Add Auth header for convenor
    add_auth_header_for(user: convenor)

    # Create a new unit as a convenor
    post '/api/units', {
      unit: {
        name: 'New Unit',
        code: 'Unit101'
      }
    }
    assert_equal 201, last_response.status, last_response_body

    unit_id = last_response_body['id']
    unit = Unit.find(unit_id)

    # Ensure that convenor is able to get this unit
    get '/api/units'
    assert_equal 200, last_response.status
    assert_equal 1, last_response_body.count
    last_response_body.each do |data|
      the_unit = Unit.find(data['id'])
      assert_equal data['id'].to_i, unit.id
      assert_equal the_unit.id, unit.id
    end

    payload = {
      unit_id: unit.id,
      exp: Time.now.to_i + 30,
      jti: SecureRandom.uuid
    }

    secret_key = Doubtfire::Application.config.lti_api_secret
    token = JWT.encode(payload, secret_key, 'HS256')

    users_can = [
      convenor,
      FactoryBot.create(:user, :admin)
    ]

    # Test to ensure convenor and admins can link the unit
    users_can.each do |_user|
      post '/api/lti/link', { ltik: token }
      assert_equal 200, last_response.status, last_response_body
    end

    # Test to ensure that convenors cant link a unit they can not already enrol students in
    payload_invalid_unit = {
      unit_id: Unit.first.id,
      exp: Time.now.to_i + 30,
      jti: SecureRandom.uuid
    }

    token_invalid_unit = JWT.encode(payload_invalid_unit, secret_key, 'HS256')

    post '/api/lti/link', { ltik: token_invalid_unit }
    assert_equal 403, last_response.status, last_response_body
    assert_equal "Not authorised to link this unit.", last_response_body['error'], last_response_body

    users_cant = [
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :tutor)
    ]

    # Ensure that students and tutors cant link the unit
    users_cant.each do |user|
      add_auth_header_for(user: user)
      post '/api/lti/link', { ltik: token }
      assert_equal 403, last_response.status, last_response_body
    end
    unit.destroy
  end

  def test_correct_roles_are_enrolled
    users = [
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :admin),
      FactoryBot.create(:user, :convenor),
      FactoryBot.create(:user, :auditor),
      FactoryBot.create(:user, :tutor)
    ]

    roles_can_be_enrolled = %w[
      Student
      Learner
    ]

    roles_cant_be_enrolled = %w[
      Admin
      Instructor
    ]

    unit = FactoryBot.create(:unit, with_students: false)

    payload = {
      unit_id: unit.id,
      member: {
        user_id: '2',
        name: 'Nickname',
        given_name: 'First name',
        family_name: 'Last name',
        email: 'email@doubtfire.com',
        ext_user_username: 'student_test_lti',
        roles: ['Learner']
      },
      exp: Time.now.to_i + 30,
      jti: SecureRandom.uuid
    }

    secret_key = Doubtfire::Application.config.lti_api_secret
    token = JWT.encode(payload, secret_key, 'HS256')

    roles_cant_be_enrolled.each do |role|
      payload[:member][:roles] = [role]

      token = JWT.encode(payload, secret_key, 'HS256')

      add_auth_header_for(user: users.sample)
      post '/api/lti/enrol', { ltik: token }

      assert_equal 204, last_response.status
    end

    roles_can_be_enrolled.each do |role|
      payload[:member][:roles] = [role]

      token = JWT.encode(payload, secret_key, 'HS256')

      add_auth_header_for(user: users.sample) # or whichever user you want as caller
      post '/api/lti/enrol', { ltik: token }

      assert_equal 201, last_response.status
      id = last_response_body['id']
      assert_not_nil id, "Expected project ID in response"

      project = Project.find(id)
      assert project.valid?, "Expected project to be created"
      assert_equal unit.id, project.unit.id
    end
  end

  def test_enrol_students_bulk
    Sidekiq::Testing.inline! do
      unit = FactoryBot.create(:unit, with_students: false)

      payload = {
        unit_id: unit.id,
        members: [
          # Valid
          {
            user_id: '1',
            name: 'Nickname 1',
            given_name: 'First name 1',
            family_name: 'Last name 1',
            email: 'email1@doubtfire.com',
            ext_user_username: 'student_test_lti1',
            roles: ['Learner']
          },
          # Valid
          {
            user_id: '2',
            name: 'Nickname 2',
            given_name: 'First name 2',
            family_name: 'Last name 2',
            email: 'email2@doubtfire.com',
            ext_user_username: 'student_test_lti2',
            roles: ['Instructor'] # This user should not be enrolled
          },
          # Valid
          {
            user_id: '3',
            name: 'Nickname 2',
            given_name: 'First name 2',
            family_name: 'Last name 2',
            email: 'email3@doubtfire.com',
            ext_user_username: 'student_test_lti3',
            roles: ['Learner', 'http://purl.imsglobal.org/vocab/lis/v2/person#Administrator']
          },
          # Error (Can't create user)
          {
            user_id: '4',
            name: 'Nickname 4',
            given_name: 'First name 4',
            family_name: 'Last name 4',
            email: 'bademail',
            ext_user_username: 'student_test_lti4',
            roles: ['Learner', 'http://purl.imsglobal.org/vocab/lis/v2/person#Administrator']
          },
          # Ignored: missing member data
          {
            # Missing user_id and roles
            name: 'Nickname 4',
            given_name: 'First name 4',
            family_name: 'Last name 4',
            email: 'email5@doubtfire.com',
            ext_user_username: 'student_test_lti4'
          }
        ],
        exp: Time.now.to_i + 30,
        jti: SecureRandom.uuid
      }

      secret_key = Doubtfire::Application.config.lti_api_secret
      token = JWT.encode(payload, secret_key, 'HS256')

      convenor = FactoryBot.create(:user, :convenor)
      unit.employ_staff(convenor, Role.convenor)

      add_auth_header_for(user: convenor)

      expected_enrolled_projects_count = 2
      expected_success_count = 3 # 2 Projects enrolled + 1 Tutor added as staff. The staff will also be added to the ignored row for not being enrolled as a project.
      expected_error_count = 1
      expected_ignore_count = 2
      assert_equal expected_enrolled_projects_count + expected_error_count + expected_ignore_count, payload[:members].count

      post '/api/lti/enrol/bulk', { ltik: token }
      assert_equal 201, last_response.status

      job = last_response_body

      assert_not_nil job['id']

      results = JSON.parse(job['result'])

      assert_equal expected_enrolled_projects_count, unit.projects.count
      assert_equal expected_success_count, results['success'].count
      assert_equal expected_error_count, results['errors'].count
      assert_equal expected_ignore_count, results['ignored'].count

      student = FactoryBot.create(:user, :student)
      unit.enrol_student(student, nil)

      # Ensure students cant access this route
      add_auth_header_for(user: student)
      post '/api/lti/enrol/bulk', { ltik: token }
      assert_equal 403, last_response.status
      Sidekiq::Testing.fake!
    end
  end

  def test_get_grades_for_members
    unit = FactoryBot.create(:unit, with_students: false)

    student1 = FactoryBot.create(:user, :student)
    student2 = FactoryBot.create(:user, :student)
    student3 = FactoryBot.create(:user, :student)
    student4 = FactoryBot.create(:user, :student)
    student5 = FactoryBot.create(:user, :student)

    project1 = unit.enrol_student(student1, nil)
    project2 = unit.enrol_student(student2, nil)
    project3 = unit.enrol_student(student3, nil)
    project4 = unit.enrol_student(student4, nil)
    # Don't enrol student5

    project1.grade = 75
    project2.grade = 52
    project3.grade = 85
    project4.grade = 0
    project1.save!
    project2.save!
    project3.save!
    project4.save!

    expected_grades = {
      student1.email.to_s => 75,
      student2.email.to_s => 52,
      student3.email.to_s => 85,
      student4.email.to_s => 0,
      student5.email.to_s => -1
    }

    project1.reload
    project2.reload
    project3.reload
    project4.reload

    tutor =  FactoryBot.create(:user, :student)
    convenor = FactoryBot.create(:user, :convenor)

    unit.employ_staff(tutor, Role.tutor)
    unit.employ_staff(convenor, Role.convenor)

    admin = FactoryBot.create(:user, :admin)
    unit.employ_staff(admin, Role.admin)

    users_cant = [
      student1,
      student2,
      student3,
      student4,
      student5,
      tutor
    ]

    users_can = [
      # Admins have :convene_units permissions, but do not have :assess permissions
      # They will instead receive -1 to indicate they dont have permissions to retrieve grades
      admin,
      convenor
    ]

    secret_key = Doubtfire::Application.config.lti_api_secret

    # Ensure we get an error if we dont pass student_emails fiel
    token_missing_emails = JWT.encode({
                                        unit_id: unit.id,
                                        exp: Time.now.to_i + 30,
                                        jti: SecureRandom.uuid
                                      }, secret_key, 'HS256')

    users_can.each do |user|
      add_auth_header_for(user: user)
      post '/api/lti/grades', { ltik: token_missing_emails }
      assert_equal 400, last_response.status
      assert_equal "Student emails field does not exist.", last_response_body['error']
    end

    # Ensure we get an error if we dont pass in an array

    token_non_array = JWT.encode({
                                   unit_id: unit.id,
                                   student_emails: "not-an-array",
                                   exp: Time.now.to_i + 30,
                                   jti: SecureRandom.uuid
                                 }, secret_key, 'HS256')

    users_can.each do |user|
      add_auth_header_for(user: user)
      post '/api/lti/grades', { ltik: token_non_array }
      assert_equal 400, last_response.status
      assert_equal "Student emails must be an array.", last_response_body['error']
    end

    payload = {
      unit_id: unit.id,
      student_emails: [
        student1.email,
        student2.email,
        student3.email,
        student4.email,
        student5.email
      ],
      exp: Time.now.to_i + 30,
      jti: SecureRandom.uuid
    }

    token = JWT.encode(payload, secret_key, 'HS256')

    users_cant.each do |user|
      add_auth_header_for(user: user)
      post '/api/lti/grades', { ltik: token }
      assert_equal 403, last_response.status
    end

    users_can.each do |user|
      add_auth_header_for(user: user)
      post '/api/lti/grades', { ltik: token }
      assert_equal 201, last_response.status
      assert_equal unit.projects.count, last_response_body.count
      last_response_body.each do |email, grade|
        if unit.role_for(user) == Role.admin
          assert_equal(-1, grade)
        else
          assert_equal(expected_grades[email], grade)
        end
        assert payload[:student_emails].include?(email)
      end
    end
  end

  def test_valid_member_data
    unit = FactoryBot.create(:unit, with_students: false)
    convenor = FactoryBot.create(:user, :convenor)
    unit.employ_staff(convenor, Role.convenor)

    secret_key = Doubtfire::Application.config.lti_api_secret

    token_missing_member = JWT.encode({
                                        unit_id: unit.id,
                                        exp: Time.now.to_i + 30,
                                        jti: SecureRandom.uuid
                                      }, secret_key, 'HS256')

    token_invalid_member_object = JWT.encode({
                                               unit_id: unit.id,
                                               member: "not-a-hash",
                                               exp: Time.now.to_i + 30,
                                               jti: SecureRandom.uuid
                                             }, secret_key, 'HS256')

    token_missing_member_fields = JWT.encode({
                                               unit_id: unit.id,
                                               member: {
                                                 user_id: nil
                                               },
                                               exp: Time.now.to_i + 30,
                                               jti: SecureRandom.uuid
                                             }, secret_key, 'HS256')

    token_member_invalid_email = JWT.encode({
                                              unit_id: unit.id,
                                              member: {
                                                user_id: '3',
                                                name: 'Nickname 2',
                                                given_name: 'First name 2',
                                                family_name: 'Last name 2',
                                                email: nil,
                                                ext_user_username: 'student_test_lti3',
                                                roles: ['Learner']
                                              },
                                              exp: Time.now.to_i + 30,
                                              jti: SecureRandom.uuid
                                            }, secret_key, 'HS256')
    add_auth_header_for(user: convenor)

    urls = [
      '/api/lti/enrol',
      '/api/auth/lti'
    ]

    urls.each do |url|
      post url, { ltik: token_missing_member }
      assert_equal 400, last_response.status
      assert last_response_body['error'].start_with?('Invalid LTI token.'), last_response_body['error']

      post url, { ltik: token_invalid_member_object }
      assert_equal 400, last_response.status
      assert last_response_body['error'].start_with?('Missing required fields:'), last_response_body['error']

      post url, { ltik: token_missing_member_fields }
      assert_equal 400, last_response.status
      assert last_response_body['error'].start_with?('Missing required fields:'), last_response_body['error']

      post url, { ltik: token_member_invalid_email }
      assert_equal 400, last_response.status
      assert last_response_body['error'].start_with?('Missing required fields:'), last_response_body['error']
    end
  end
end
