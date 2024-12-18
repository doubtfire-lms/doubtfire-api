require 'test_helper'

class D2lTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_can_add_d2l_details_to_unit
    unit = FactoryBot.create(:unit, with_students: false)

    add_auth_header_for(user: User.first)

    initial_count = D2lAssessmentMapping.count

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '12345' }
    assert_equal 201, last_response.status, last_response.inspect

    assert_equal initial_count + 1, D2lAssessmentMapping.count
    assert_equal '12345', D2lAssessmentMapping.last.org_unit_id
    assert_equal unit.id, D2lAssessmentMapping.last.unit_id

    assert_equal unit.d2l_assessment_mapping, D2lAssessmentMapping.last
  end

  def test_ensure_only_one_d2l_mapping_per_unit
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: User.first)

    initial_count = D2lAssessmentMapping.count

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '54321' }
    assert_equal 400, last_response.status, last_response.inspect

    assert_equal initial_count, D2lAssessmentMapping.count
  end

  def test_convenor_needed_for_d2l_details
    unit = FactoryBot.create(:unit, with_students: false)
    user = FactoryBot.create(:user, :student)
    add_auth_header_for(user: user)

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '12345' }
    assert_equal 403, last_response.status, last_response.inspect

    user = FactoryBot.create(:user, :tutor)
    add_auth_header_for(user: user)

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '12345' }
    assert_equal 403, last_response.status, last_response.inspect

    user = FactoryBot.create(:user, :auditor)
    add_auth_header_for(user: user)

    post "/api/units/#{unit.id}/d2l", { org_unit_id: '12345' }
    assert_equal 403, last_response.status, last_response.inspect
  end

  def test_can_get_d2l_details_for_unit
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: unit.main_convenor_user)

    get "/api/units/#{unit.id}/d2l"
    assert_equal 200, last_response.status, last_response.inspect

    assert_equal '12345', last_response_body['org_unit_id'], last_response_body
    assert_equal d2l.id, last_response_body['id']
  end

  def test_can_delete_d2l_details_for_unit
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: unit.main_convenor_user)

    initial_count = D2lAssessmentMapping.count

    delete "/api/units/#{unit.id}/d2l"
    assert_equal 204, last_response.status, last_response.inspect

    assert_equal initial_count - 1, D2lAssessmentMapping.count

    unit.reload
    assert_nil unit.d2l_assessment_mapping
  end

  def test_can_update_d2l_details_for_unit
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    add_auth_header_for(user: unit.main_convenor_user)

    initial_count = D2lAssessmentMapping.count

    put "/api/units/#{unit.id}/d2l", { org_unit_id: '54321' }
    assert_equal 200, last_response.status, last_response.inspect

    assert_equal initial_count, D2lAssessmentMapping.count

    unit.reload
    assert_equal '54321', unit.d2l_assessment_mapping.org_unit_id
  end

  def test_can_login_to_d2l
    user = FactoryBot.create(:user, :convenor)
    add_auth_header_for(user: user)

    init_states = UserOauthState.count

    stub_request(:post, "https://auth.brightspace.com/core/connect/token")
      .to_return(
        status: 200,
        body: {
          'access_token' => "blah",
          'expires_at' => '1734493629',
          'refresh_token' => "blee.bloo",
          'scope' => "core:*:* enrollment:orgunit:read grades:*:*",
          'token_type' => "Bearer"
        }.to_json,
        headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
      )

    post '/api/d2l/login_url'
    assert_equal 201, last_response.status, last_response.inspect

    # State is created for callback
    assert_equal init_states + 1, UserOauthState.count

    state = UserOauthState.last.state

    init_tokens = user.user_oauth_tokens.count

    # When the user logs in, they are redirected to the callback
    get '/api/d2l/callback', { code: '12345', state: state }
    assert_equal 200, last_response.status, last_response.inspect

    # The user should now have an oauth token
    user.reload
    assert_equal init_tokens + 1, user.user_oauth_tokens.count
  end

  def test_login_to_d2l_exposed_over_api
    unit = FactoryBot.create(:unit, with_students: false)

    add_auth_header_for(user: unit.main_convenor_user)

    post '/api/d2l/login_url'
    assert_equal 201, last_response.status, last_response.inspect

    assert_equal unit.main_convenor_user, UserOauthState.last.user
  end

  def test_old_state_and_oauth_tokens_are_destroyed
    user = FactoryBot.create(:user, :convenor)
    add_auth_header_for(user: user)

    state = UserOauthState.create(user: user, state: '12345')
    state.created_at = 31.minutes.ago
    state.save

    UserOauthState.destroy_old_states

    assert_nil UserOauthState.find_by(id: state.id)

    token = UserOauthToken.create(user: user, provider: :d2l, token: 'test', expires_at: 31.minutes.ago)

    UserOauthToken.destroy_old_tokens

    assert_nil UserOauthToken.find_by(id: token.id)
  end

  def test_post_grades_requires_org_unit_id
    unit = FactoryBot.create(:unit, with_students: false)

    assert_raises(StandardError) do
      D2lIntegration.post_grades(unit, unit.main_convenor_user)
    end
  end

  def test_post_grades_requires_user_oauth_token
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    assert_raise(StandardError) do
      D2lIntegration.post_grades(unit, unit.main_convenor_user)
    end

    UserOauthToken.create(user: unit.main_convenor_user, provider: :d2l, token: 'test', expires_at: 30.minutes.from_now)

    assert_raises(StandardError) do
      D2lIntegration.post_grades(unit, User.first)
    end
  end

  def test_does_grade_item_exist
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345', grade_object_id: '54321')
    UserOauthToken.create(user: unit.main_convenor_user, provider: :d2l, token: 'test', expires_at: 30.minutes.from_now)

    grade_request = stub_request(:get, "https://api.brightspace.com/d2l/api/le/1.47/12345/grades/54321")
                    .to_return(
                      { status: 404, headers: {} },
                      { status: 200, body: { id: '54321' }.to_json, headers: { 'Content-Type' => 'application/json;charset=UTF-8' } }
                    )

    assert_not D2lIntegration.does_grade_item_exist?(d2l, UserOauthToken.last.access_token)
    assert_requested(grade_request, times: 1)

    # restore grade object id
    d2l.grade_object_id = '54321'
    d2l.save

    assert D2lIntegration.does_grade_item_exist?(d2l, UserOauthToken.last.access_token)
    assert_requested(grade_request, times: 2)
  end

  def test_create_grade_item
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')
    UserOauthToken.create(user: unit.main_convenor_user, provider: :d2l, token: 'test', expires_at: 30.minutes.from_now)

    post_grade_request =  stub_request(:post, "https://api.brightspace.com/d2l/api/le/1.47/12345/grades/")
                          .to_return(
                            status: 200,
                            body: {
                              "Id" => "jskldfj081123"
                            }.to_json,
                            headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
                          )

    D2lIntegration.create_grade_item(d2l, UserOauthToken.last.access_token)

    assert_requested post_grade_request, times: 1
    assert_equal 'jskldfj081123', d2l.grade_object_id
    assert d2l.persisted?
  end

  def test_get_class_list
    unit = FactoryBot.create(:unit, with_students: false)
    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')
    UserOauthToken.create(user: unit.main_convenor_user, provider: :d2l, token: 'test', expires_at: 30.minutes.from_now)

    class_list_request =  stub_request(:get, "https://api.brightspace.com/d2l/api/le/1.47/12345/classlist/")
                          .to_return(
                            status: 200,
                            body: [
                              {
                                "Identifier" => "12345",
                                "FirstName" => "John",
                                "LastName" => "Doe",
                                "UserName" => "johndoe",
                                "OrgDefinedId" => "s12345",
                                "Email" => "s12345@test.com"
                              },
                              {
                                "Identifier" => "12346",
                                "FirstName" => "Jane",
                                "LastName" => "Doe",
                                "UserName" => "johndoe",
                                "OrgDefinedId" => "s12346",
                                "Email" => "s12346@test.com"
                              }
                            ].to_json,
                            headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
                          )

    list = D2lIntegration.get_class_list(d2l, UserOauthToken.last.access_token)

    assert_requested class_list_request, times: 1
    assert_equal 2, list.count
  end

  def test_post_grades
    # Create unit, d2l mapping, and user oauth token
    unit = FactoryBot.create(:unit, with_students: false)

    p1 = unit.enrol_student(FactoryBot.create(:user, :student), Campus.first)
    p2 = unit.enrol_student(FactoryBot.create(:user, :student), Campus.first)
    p3 = unit.enrol_student(FactoryBot.create(:user, :student), Campus.first)
    p4 = unit.enrol_student(FactoryBot.create(:user, :student), Campus.first)

    s1 = other_student = FactoryBot.create(:user, :student)

    p1.update(grade: 50)
    p2.update(grade: 60)
    p3.update(enrolled: false)
    p4.update(grade: 70)

    assert_equal 3, unit.active_projects.count
    assert_equal 4, unit.projects.count

    post_grade_request =  stub_request(:post, "https://api.brightspace.com/d2l/api/le/1.47/12345/grades/")
                          .to_return(
                            status: 200,
                            body: {
                              "Id" => "jskldfj081123"
                            }.to_json,
                            headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
                          )

    class_list_request =  stub_request(:get, "https://api.brightspace.com/d2l/api/le/1.47/12345/classlist/")
                          .to_return(
                            status: 200,
                            body: [
                              {
                                "Identifier" => "12345",
                                "FirstName" => p1.student.first_name,
                                "LastName" => p1.student.last_name,
                                "UserName" => p1.student.username,
                                "OrgDefinedId" => p1.student.student_id,
                                "Email" => p1.student.email
                              },
                              {
                                "Identifier" => "12346",
                                "FirstName" => p2.student.first_name,
                                "LastName" => p2.student.last_name,
                                "UserName" => p2.student.username,
                                "OrgDefinedId" => "#{p2.student.student_id} - somehow mismatch",
                                "Email" => p2.student.email
                              },
                              {
                                "Identifier" => "12347",
                                "FirstName" => p3.student.first_name,
                                "LastName" => p3.student.last_name,
                                "UserName" => "#{p3.student.username} - somehow mismatch",
                                "OrgDefinedId" => "#{p3.student.student_id} - somehow mismatch",
                                "Email" => p3.student.email
                              },
                              {
                                "Identifier" => "12348",
                                "FirstName" => s1.first_name,
                                "LastName" => s1.last_name,
                                "UserName" => s1.username,
                                "OrgDefinedId" => s1.student_id,
                                "Email" => s1.email
                              }
                            ].to_json,
                            headers: { 'Content-Type' => 'application/json;charset=UTF-8' }
                          )

    assert_equal p1, D2lIntegration.find_project_for_d2l_user(unit, { "OrgDefinedId" => p1.student.student_id, "UserName" => p1.student.username, "Email" => p1.student.email } )
    assert_equal p2, D2lIntegration.find_project_for_d2l_user(unit, { "OrgDefinedId" => 'BLAH', "UserName" => p2.student.username, "Email" => p2.student.email } )
    assert_equal p3, D2lIntegration.find_project_for_d2l_user(unit, { "OrgDefinedId" => 'BLAH', "UserName" => 'BLEE', "Email" => p3.student.email } )
    assert_nil D2lIntegration.find_project_for_d2l_user(unit, { "OrgDefinedId" => 'BLAH', "UserName" => 'BLEE', "Email" => 'BLAH' } )

    p1_put_request =  stub_request(:put, "https://api.brightspace.com/d2l/api/le/1.47/12345/grades/jskldfj081123/values/12345")
                      .with(
                        body: { "GradeObjectType" => "1", "PointsNumerator" => "50" }
                      ).to_return(
                        status: 200,
                        headers: {
                          'X-Rate-Limit-Remaining' => 2,
                          'X-Request-Cost' => 1,
                          'X-Rate-Limit-Reset' => 1
                        }
                      )

    p2_put_request =  stub_request(:put, "https://api.brightspace.com/d2l/api/le/1.47/12345/grades/jskldfj081123/values/12346")
                      .with(
                        body: { "GradeObjectType" => "1", "PointsNumerator" => "60" }
                      ).to_return(status: 200, headers: {})

    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')
    UserOauthToken.create(user: unit.main_convenor_user, provider: :d2l, token: 'test', expires_at: 30.minutes.from_now)

    # result = D2lIntegration.post_grades(unit, unit.main_convenor_user)
    D2lPostGradesJob.perform_async(unit.id, unit.main_convenor_user.id)
    D2lPostGradesJob.drain

    assert File.exist?(D2lIntegration.result_file_path(unit))
    result = File.read(D2lIntegration.result_file_path(unit)).split("\n")

    assert_requested post_grade_request, times: 1
    assert_requested class_list_request, times: 1

    assert_equal 6, result.count, result

    assert_includes result[1], "Success, Posted grade for #{p1.student.username}"
    assert_includes result[2], "Success, Posted grade for #{p2.student.username}"
    assert_includes result[3], "Skipped, No grade for #{p3.student.username}"
    assert_includes result[4], "Not Found in OnTrack, No OnTrack details for #{s1.username}"
    assert_includes result[5], "Not Found in D2L, #{p4.student.username}"

    add_auth_header_for(user: unit.main_convenor_user)
    get "/api/units/#{unit.id}/d2l/grades"
    assert_equal 200, last_response.status, last_response.inspect

    assert_equal 'text/csv', last_response.headers['Content-Type']
    result = last_response.body.split("\n")
    assert_equal 6, result.count, result
    assert_includes result[1], "Success, Posted grade for #{p1.student.username}"
  end

  def test_request_grade_transfer
    unit = FactoryBot.create(:unit, with_students: false)

    add_auth_header_for(user: unit.main_convenor_user)

    # Call without d2l mapping
    post "/api/units/#{unit.id}/d2l/grades"
    assert_equal 403, last_response.status, last_response.inspect

    d2l = D2lAssessmentMapping.create(unit: unit, org_unit_id: '12345')

    # Call without user oauth token

    post "/api/units/#{unit.id}/d2l/grades"
    assert_equal 403, last_response.status, last_response.inspect

    token = UserOauthToken.create(user: unit.main_convenor_user, provider: :d2l, token: 'test', expires_at: 2.minutes.from_now)

    # Call with old token
    post "/api/units/#{unit.id}/d2l/grades"
    assert_equal 403, last_response.status, last_response.inspect

    # Call with everything set up
    token.update(expires_at: 30.minutes.from_now)

    post "/api/units/#{unit.id}/d2l/grades"
    assert_equal 202, last_response.status, last_response.inspect

    assert_equal 1, D2lPostGradesJob.jobs.count
  end
end
