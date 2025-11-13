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
                               priority: 1
                             })

    DiscussionPrompt.create!({
                               task_definition: td2,
                               content: 'Ask the student about passing values by reference...',
                               priority: 2
                             })

    DiscussionPrompt.create!({
                               task_definition: td1,
                               content: 'Potential use of GenAI, ask the student to explain their code...',
                               priority: 3
                             })

    DiscussionPrompt.create!({
                               task_definition: td2,
                               content: 'Ask student to explain why they used std:cin over read_line()...',
                               priority: 4
                             })

    DiscussionPrompt.create!({
                               task_definition: td2,
                               content: 'Ask student to explain why they used std:cin over read_line()... 1',
                               priority: 4
                             })

    add_auth_header_for(user: user)

    get "/api/task_definitions/#{td1.id}/discussion_prompts"
    assert_equal 200, last_response.status, last_response_body.inspect
    assert_equal 2, last_response_body.count

    get "/api/task_definitions/#{td2.id}/discussion_prompts"
    assert_equal 200, last_response.status, last_response_body.inspect
    assert_equal 3, last_response_body.count

    project1_task1 =  project1.task_for_task_definition(td1)
    project1_task2 =  project1.task_for_task_definition(td2)

    project2_task1 =  project2.task_for_task_definition(td1)
    project2_task2 =  project2.task_for_task_definition(td2)

    project1_task1.update!(task_status: TaskStatus.discuss)
    project1_task2.update!(task_status: TaskStatus.complete)

    project2_task1.update!(task_status: TaskStatus.ready_for_feedback)
    project2_task2.update!(task_status: TaskStatus.complete)

    get "/api/projects/#{project1.id}/discussion_prompts"
    assert_equal 200, last_response.status, last_response_body.inspect
    assert_equal 2, last_response_body.count

    project1_task2.update!(task_status: TaskStatus.discuss)

    get "/api/projects/#{project1.id}/discussion_prompts"
    assert_equal 200, last_response.status, last_response_body.inspect
    assert_equal 5, last_response_body.count

    get "/api/projects/#{project2.id}/discussion_prompts"
    assert_equal 200, last_response.status, last_response_body.inspect
    assert_equal 0, last_response_body.count
  end

  def test_student_dicussion_prompts_permissions
    unit = FactoryBot.create(:unit)
    convenor = FactoryBot.create(:user, :convenor)
    tutor = FactoryBot.create(:user, :tutor)

    unit.employ_staff(convenor, Role.convenor)
    unit.employ_staff(tutor, Role.tutor)

    td = FactoryBot.create(:task_definition, unit: unit)

    student = FactoryBot.create(:user, :student)
    project = unit.enrol_student(student, nil)

    users_can = [convenor, tutor]

    users_cant = [student]

    users_can.each do |user|
      add_auth_header_for(user: user)

      get "/api/task_definitions/#{td.id}/discussion_prompts"
      assert_equal 200, last_response.status, last_response_body

      post "/api/task_definitions/#{td.id}/discussion_prompts", {
        content: 'test content 123',
        priority: 1
      }
      assert_equal 201, last_response.status, last_response_body

      last_prompt = DiscussionPrompt.last

      assert_not_nil last_prompt
      assert_equal 'test content 123', last_prompt.content
      assert_equal 1, last_prompt.priority

      put "/api/task_definitions/#{td.id}/discussion_prompts/#{last_prompt.id}", {
        content: 'test content 456',
        priority: 2
      }
      assert_equal 200, last_response.status, last_response_body
      last_prompt.reload
      assert_equal 'test content 456', last_prompt.content
      assert_equal 2, last_prompt.priority

      delete "/api/task_definitions/#{td.id}/discussion_prompts/#{last_prompt.id}"
      assert_equal 200, last_response.status, last_response_body
      assert_nil DiscussionPrompt.find_by(id: last_prompt.id)

      get "/api/projects/#{project.id}/discussion_prompts"
      assert_equal 200, last_response.status, last_response_body
    end

    users_cant.each do |user|
      add_auth_header_for(user: user)

      get "/api/task_definitions/#{td.id}/discussion_prompts"
      assert_equal 403, last_response.status, last_response_body

      post "/api/task_definitions/#{td.id}/discussion_prompts", {
        content: 'test',
        priority: 0
      }
      assert_equal 403, last_response.status, last_response_body

      put "/api/task_definitions/#{td.id}/discussion_prompts/1", {
        content: 'test',
        priority: 0
      }
      assert_equal 403, last_response.status, last_response_body

      delete "/api/task_definitions/#{td.id}/discussion_prompts/1"
      assert_equal 403, last_response.status, last_response_body

      get "/api/projects/#{project.id}/discussion_prompts"
      assert_equal 403, last_response.status, last_response_body
    end
  end

end
