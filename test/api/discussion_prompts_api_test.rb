require 'test_helper'
require 'date'
require './lib/helpers/database_populator'

class DiscussionPromptsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_dicussion_prompts_filters
    # Create discussion prompts for task definition
    unit = FactoryBot.create(:unit)
    user = FactoryBot.create(:user, :convenor)
    unit.employ_staff(user, Role.convenor)

    td1 = FactoryBot.create(:task_definition, unit: unit)
    td2 = FactoryBot.create(:task_definition, unit: unit)

    assert_not_nil td1
    assert_not_nil td2

    student1 = FactoryBot.create(:user, :student)
    student2 = FactoryBot.create(:user, :student)

    project1 = unit.enrol_student(student1, nil)
    project2 = unit.enrol_student(student2, nil)

    # Create global prompts (for task definitions)
    DiscussionPrompt.create!({
                               task_definition: td1,
                               content: 'Ask the student about pointers and references...',
                               weight: 1,
                               project: nil
                             })

    DiscussionPrompt.create!({
                               task_definition: td2,
                               content: 'Ask the student about passing values by reference...',
                               weight: 2,
                               project: nil
                             })

    # Create prompts specific to a project
    DiscussionPrompt.create!({
                               task_definition: td1,
                               content: 'Potential use of GenAI, ask the student to explain their code...',
                               weight: 3,
                               project: project1,
                               created_by: user
                             })

    DiscussionPrompt.create!({
                               task_definition: td2,
                               content: 'Ask student to explain why they used std:cin over read_line()...',
                               weight: 4,
                               project: project2,
                               created_by: user
                             })

    add_auth_header_for(user: user)

    get "/api/task_definitions/#{td1.id}/discussion_prompts"
    assert_equal 200, last_response.status, last_response_body.inspect

    # Ensure we don't get the discussion prompt unique to a project
    assert_equal 1, last_response_body.count

    get "/api/projects/#{project1.id}/task_definitions/#{td1.id}/discussion_prompts"
    assert_equal 200, last_response.status, last_response_body.inspect

    # Ensure we get the global + unique discussion prompt
    assert_equal 2, last_response_body.count
    # Ensure the prompts are ordered by weight
    assert_equal 'Potential use of GenAI, ask the student to explain their code...', last_response_body.first['content']
    assert_equal 'Ask the student about pointers and references...', last_response_body.second['content']

    get "/api/projects/#{project1.id}/task_definitions/#{td2.id}/discussion_prompts"
    assert_equal 200, last_response.status, last_response_body.inspect
    # Ensure we get the single global prompt
    assert_equal 1, last_response_body.count

    get "/api/projects/#{project2.id}/task_definitions/#{td2.id}/discussion_prompts"
    assert_equal 200, last_response.status, last_response_body.inspect

    # Ensure we get the global + unique discussion prompt
    assert_equal 2, last_response_body.count
    # Ensure the prompts are ordered by weight
    assert_equal 'Ask student to explain why they used std:cin over read_line()...', last_response_body.first['content']
    assert_equal 'Ask the student about passing values by reference...', last_response_body.second['content']
  end

  def test_student_dicussion_prompts_permissions
    # Ensure student cant GET discussion prompts
    # Ensure student cant POST discussion prompts
    # Ensure student cant PUT discussion prompts
    # Ensure student cant DELETE discussion prompts
    # Ensure tutors & convenors can GET discussion prompts
    # Ensure tutors & convenors can POST discussion prompts
    # Ensure tutors & convenors can PUT discussion prompts
    # Ensure tutors & convenors can DELETE discussion prompts
  end

end
