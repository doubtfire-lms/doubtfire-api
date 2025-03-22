require 'test_helper'

class FeedbackChipApiTestCondolidated < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_auth_for_create_edit_unit_feedback_chips
    unit = FactoryBot.create(:unit, with_students: false)
    admin = FactoryBot.create(:user, :admin)
    tutor = FactoryBot.create(:user, :tutor)

    learning_outcomes = [
      unit.learning_outcomes.first,
      unit.task_definitions.first.learning_outcomes.first
    ]

    unit.employ_staff(tutor, Role.tutor)

    users_can = [
      unit.main_convenor_user,
      admin
    ]
    users_cant = [
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :tutor),
      tutor,
      FactoryBot.create(:user, :convenor),
      FactoryBot.create(:user, :auditor)
    ]

    data_to_post = {
      type: 'group',
      chip_text: 'Sample chip text',
      description: 'Sample description',
      parent_chip_id: nil,
      learning_outcome_id: nil
    }

    data_to_put = {
      chip_text: 'Updated text'
    }

    learning_outcomes.each do |lo|
      FactoryBot.create(:feedback_group_chip, learning_outcome_id: lo.id)
    end

    users_can.each do |user|
      add_auth_header_for user: user
      learning_outcomes.each do |lo|
        data_to_post[:learning_outcome_id] = lo.id
        chip_count = lo.feedback_chips.count

        post_json 'api/feedback_chips', data_to_post
        assert_equal 201, last_response.status, "User #{user.role.name} should be able to create feedback chips for #{lo.context_type} #{lo.context_type}"
        assert_equal chip_count + 1, lo.feedback_chips.count

        last_chip = Feedback::FeedbackGroupChip.find(last_response_body['id'])

        put_json "api/feedback_chips/#{last_chip.id}", data_to_put
        assert_equal 200, last_response.status, "User #{user.role.name} should be able to update feedback chips for #{lo.context_type}"

        # Clean up
        Feedback::FeedbackGroupChip.last.destroy
      end
    end

    users_cant.each do |user|
      add_auth_header_for user: user

      learning_outcomes.each do |lo|
        data_to_post[:learning_outcome_id] = lo.id
        chip_count = lo.feedback_chips.count

        post_json 'api/feedback_chips', data_to_post
        assert_equal 403, last_response.status, "User #{user.role.name} should not be able to create feedback chips"
        assert_equal chip_count, lo.feedback_chips.count

        last_chip = lo.feedback_chips.last

        put_json "api/feedback_chips/#{last_chip.id}", data_to_put
        assert_equal 403, last_response.status, "User #{user.role.name} should not be able to update feedback chips for #{lo.context_type}"
      end
    end
  end

  def test_auth_for_create_edit_global_feedback_chips
    admin = FactoryBot.create(:user, :admin)

    learning_outcome = LearningOutcome.global_outcomes.first

    users_can = [
      admin
    ]
    users_cant = [
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :tutor),
      FactoryBot.create(:user, :convenor),
      FactoryBot.create(:user, :auditor)
    ]

    data_to_post = {
      type: 'group',
      chip_text: 'Sample chip text',
      description: 'Sample description',
      parent_chip_id: nil,
      learning_outcome_id: learning_outcome.id
    }

    data_to_put = {
      chip_text: 'Updated text',
    }

    FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)

    chip_count = learning_outcome.feedback_chips.count

    users_can.each do |user|
      add_auth_header_for user: user

      post_json 'api/feedback_chips', data_to_post
      assert_equal 201, last_response.status, "User #{user.role.name} should be able to create feedback chips"
      assert_equal chip_count + 1, learning_outcome.feedback_chips.count

      last_chip = Feedback::FeedbackGroupChip.find(last_response_body['id'])

      put_json "api/feedback_chips/#{last_chip.id}", data_to_put
      assert_equal 200, last_response.status, "User #{user.role.name} should be able to update feedback chips. #{last_response_body}"

      # Clean up
      Feedback::FeedbackGroupChip.last.destroy
    end

    users_cant.each do |user|
      add_auth_header_for user: user

      post_json 'api/feedback_chips', data_to_post
      assert_equal 403, last_response.status, "User #{user.role.name} should not be able to create feedback chips"
      assert_equal chip_count, learning_outcome.feedback_chips.count

      last_chip = LearningOutcome.global_outcomes.first.feedback_chips.last

      put_json "api/feedback_chips/#{last_chip.id}", data_to_put
      assert_equal 403, last_response.status, "User #{user.role.name} should not be able to update feedback chips"
    end
  end

  def test_auth_for_get_unit_feedback_chips
    start_inside = DateTime.now - Doubtfire::Application.config.auditor_unit_access_years + 1.week
    end_inside = DateTime.now - 1.week

    unit = FactoryBot.create(:unit, student_count: 1, start_date: start_inside, end_date: end_inside)
    admin = FactoryBot.create(:user, :admin)
    tutor = FactoryBot.create(:user, :tutor)
    auditor = FactoryBot.create(:user, :auditor)
    student = unit.students.first

    learning_outcomes = [
      {
        url: "/api/units/#{unit.id}/feedback_chips",
        outcome: unit.learning_outcomes.first
      },
      {
        url: "/api/task_definitions/#{unit.task_definitions.first.id}/feedback_chips",
        outcome: unit.task_definitions.first.learning_outcomes.first
      }
    ]

    unit.employ_staff(tutor, Role.tutor)

    users_can = [
      unit.main_convenor_user,
      admin,
      tutor,
      auditor
    ]
    users_cant = [
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :tutor),
      FactoryBot.create(:user, :convenor),
      student.user
    ]

    assert_equal Role.auditor, unit.role_for(auditor)

    users_can.each do |user|
      add_auth_header_for user: user
      learning_outcomes.each do |lo_data|
        lo = lo_data[:outcome]
        url = lo_data[:url]

        chip_count = lo.feedback_chips.count

        get url
        assert_equal 200, last_response.status, "User #{user.role.name} should be able to get feedback chips for #{lo.context_type}"
        assert_equal chip_count, last_response_body.count, last_response_body
      end
    end

    users_cant.each do |user|
      add_auth_header_for user: user

      learning_outcomes.each do |lo_data|
        lo = lo_data[:outcome]
        url = lo_data[:url]

        chip_count = lo.feedback_chips.count

        get url
        assert_equal 403, last_response.status, "User #{user.role.name} should not be able to get feedback chips"
      end
    end
  end

  def test_auth_for_get_global_feedback_chips
    users_can = [
      FactoryBot.create(:user, :tutor),
      FactoryBot.create(:user, :convenor),
      FactoryBot.create(:user, :auditor),
      FactoryBot.create(:user, :admin)
    ]
    users_cant = [
      FactoryBot.create(:user, :student)
    ]

    users_can.each do |user|
      add_auth_header_for user: user
      chip_count = LearningOutcome.global_outcomes.includes(:feedback_chips).map(&:feedback_chips).flatten.count

      get "/api/global/feedback_chips"
      assert_equal 200, last_response.status, "User #{user.role.name} should be able to get feedback chips"
      assert_equal chip_count, last_response_body.count, last_response_body
    end

    users_cant.each do |user|
      add_auth_header_for user: user
      get "/api/global/feedback_chips"
      assert_equal 403, last_response.status, "User #{user.role.name} should not be able to get feedback chips"
    end
  end

  def test_auth_for_delete_feedback_chips
    start_inside = DateTime.now - Doubtfire::Application.config.auditor_unit_access_years + 1.week
    end_inside = DateTime.now - 1.week

    unit = FactoryBot.create(:unit, student_count: 1, start_date: start_inside, end_date: end_inside)
    admin = FactoryBot.create(:user, :admin)
    tutor = FactoryBot.create(:user, :tutor)
    auditor = FactoryBot.create(:user, :auditor)
    student = unit.students.first


    learning_outcomes = [
      {
        learning_outcome: unit.learning_outcomes.first,
        context: 'ULO'
      },
      {
        learning_outcome: unit.task_definitions.first.learning_outcomes.first,
        context: 'TLO'
      }
    ]

    unit.employ_staff(tutor, Role.tutor)

    users_can = [
      unit.main_convenor_user,
      admin
    ]
    users_cant = [
      tutor,
      auditor,
      FactoryBot.create(:user, :student),
      FactoryBot.create(:user, :tutor),
      FactoryBot.create(:user, :convenor),
      student.user
    ]

    assert_equal Role.auditor, unit.role_for(auditor)

    users_can.each do |user|
      add_auth_header_for user: user
      learning_outcomes.each do |lo_data|
        lo = lo_data[:learning_outcome]
        context = lo_data[:context]

        chip = FactoryBot.create(:feedback_template_chip, learning_outcome_id: lo.id)

        chip_count = lo.feedback_chips.count

        delete "api/feedback_chips/#{chip.id}"
        assert_equal 204, last_response.status, "User #{user.role.name} should be able to delete #{context} feedback chips"
        assert_equal chip_count - 1, lo.feedback_chips.count
      end
    end

    users_cant.each do |user|
      add_auth_header_for user: user

      learning_outcomes.each do |lo_data|
        lo = lo_data[:learning_outcome]
        context = lo_data[:context]

        chip = FactoryBot.create(:feedback_template_chip, learning_outcome_id: lo.id)

        chip_count = lo.feedback_chips.count

        delete "api/feedback_chips/#{chip.id}"
        assert_equal 403, last_response.status, "User #{user.role.name} should not be able to delete #{context} feedback chips"
        assert_equal chip_count, lo.feedback_chips.count
      end
    end
  end

  def test_create_feedback_group_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    data_to_post = {
      type: 'group',
      chip_text: 'Sample chip text',
      description: 'Sample description',
      parent_chip_id: nil,
      learning_outcome_id: learning_outcome.id
    }

    chip_count = learning_outcome.feedback_chips.count

    add_auth_header_for user: User.first
    post_json 'api/feedback_chips', data_to_post
    assert_equal 201, last_response.status

    assert_equal chip_count + 1, learning_outcome.feedback_chips.count

    response_keys = %w[id chip_text description parent_chip_id learning_outcome_id]
    data = last_response_body
    assert_json_matches_model Feedback::FeedbackGroupChip.last, data, response_keys
    assert_equal Feedback::FeedbackGroupChip.last.id, data['id']
  end

  def test_create_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    data_to_post = {
      type: 'template',
      chip_text: 'Sample chip text',
      description: 'Sample description',
      learning_outcome_id: learning_outcome.id,
      task_status: TaskStatus.complete.name,
      comment_text: 'Sample comment text',
      summary_text: 'Sample summary text'
    }
    add_auth_header_for user: User.first

    chip_count = learning_outcome.feedback_chips.count

    post_json 'api/feedback_chips', data_to_post
    assert_equal 201, last_response.status

    assert_equal chip_count + 1, learning_outcome.feedback_chips.count

    response_keys = %w[id chip_text description learning_outcome_id task_status comment_text summary_text]
    data = last_response_body
    assert_json_matches_model Feedback::FeedbackTemplateChip.last, data, response_keys
    assert_equal Feedback::FeedbackTemplateChip.last.id, data['id']
  end

  def test_create_feedback_template_chip_with_parent
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    data_to_post = {
      type: 'template',
      chip_text: 'Sample chip text',
      description: 'Sample description',
      parent_chip_id: group_chip.id,
      learning_outcome_id: learning_outcome.id,
      task_status: TaskStatus.complete.name,
      comment_text: 'Sample comment text',
      summary_text: 'Sample summary text'
    }
    add_auth_header_for user: User.first

    chip_count = learning_outcome.feedback_chips.count

    post_json 'api/feedback_chips', data_to_post
    assert_equal 201, last_response.status

    assert_equal chip_count + 1, learning_outcome.feedback_chips.count

    response_keys = %w[id chip_text description learning_outcome_id parent_chip_id task_status comment_text summary_text]
    data = last_response_body
    assert_json_matches_model Feedback::FeedbackTemplateChip.last, data, response_keys
    assert_equal Feedback::FeedbackTemplateChip.last.id, data['id']
  end

  def test_get_all_feedback_chips_for_a_context
    unit = FactoryBot.create(:unit, with_students: false, task_count: 0, outcome_count: 0)
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit')
    group_chip_lo1 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip_lo1 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip_lo1.id)
    template_chip2_lo1 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip_lo1.id)
    group_chip_lo2 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome2.id)
    template_chip_lo2 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome2.id, parent_chip_id: group_chip_lo2.id)
    template_chip2_lo2 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome2.id, parent_chip_id: group_chip_lo2.id)
    add_auth_header_for user: User.first
    get "api/units/#{unit.id}/feedback_chips"
    assert_equal 200, last_response.status

    assert_equal 6, last_response_body.count, last_response_body

    chips = [learning_outcome.feedback_chips.pluck(:id), learning_outcome2.feedback_chips.pluck(:id)].flatten

    last_response_body.each do |line|
      assert chips.include?(line['id']), "Found unknown chip #{line}"
    end
  end

  def test_update_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'chippy', description: 'blah blah', comment_text: 'your work is horrible', summary_text: 'just plain bad', task_status: TaskStatus.complete.name, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    data_to_put = {
      chip_text: 'updated chip',
      description: 'updated description'
    }
    add_auth_header_for user: User.first
    put_json "api/feedback_chips/#{template_chip.id}", data_to_put
    assert_equal 200, last_response.status

    template_chip.reload
    assert_json_matches_model template_chip, last_response_body, %w[id chip_text description]
    assert_json_matches_model template_chip, data_to_put, %w[chip_text description]
  end

  def test_update_feedback_group_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    data_to_put = {
      chip_text: 'updated chip text',
      description: 'updated description'
    }
    add_auth_header_for user: User.first
    put_json "api/feedback_chips/#{group_chip.id}", data_to_put
    assert_equal 200, last_response.status

    group_chip.reload
    assert_json_matches_model group_chip, last_response_body, %w[id chip_text description]
    assert_json_matches_model group_chip, data_to_put, %w[chip_text description]
  end

  def test_delete_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'chippy', description: 'blah blah', comment_text: 'your work is horrible', summary_text: 'just plain bad', task_status: TaskStatus.complete.name, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    add_auth_header_for user: User.first

    chip_count = learning_outcome.feedback_chips.count

    delete "api/feedback_chips/#{template_chip.id}"
    assert_equal 204, last_response.status

    assert_equal chip_count - 1, learning_outcome.feedback_chips.count
  end

  def test_delete_feedback_group_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'chippy', description: 'blah blah', comment_text: 'your work is great', summary_text: 'well done', task_status: TaskStatus.complete.name, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)

    add_auth_header_for user: User.first

    chip_count = learning_outcome.feedback_chips.count

    delete "api/feedback_chips/#{group_chip.id}"
    assert_equal 204, last_response.status

    assert_equal chip_count - 1, learning_outcome.feedback_chips.count
  end

  def test_cannot_change_chip_type_t_to_g
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'chippy', description: 'blah blah', comment_text: 'your work is horrible', summary_text: 'just plain bad', task_status: TaskStatus.complete.name, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)

    data_to_put = {
      type: 'group',
      chip_text: 'Sample chip text',
      description: 'Sample description'
    }
    add_auth_header_for user: User.first
    put_json "api/feedback_chips/#{template_chip.id}", data_to_put
    assert_equal 200, last_response.status

    template_chip.reload
    assert_equal 'Feedback::FeedbackTemplateChip', template_chip.type
  end

  def test_cannot_change_chip_type_g_to_t
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)

    data_to_post = {
      type: 'template',
      chip_text: 'Sample chip text',
      description: 'Sample description',
      parent_chip_id: nil,
      learning_outcome_id: learning_outcome.id,
      task_status: TaskStatus.complete.name,
      comment_text: 'Sample comment text',
      summary_text: 'Sample summary text'
    }
    add_auth_header_for user: User.first
    put_json "api/feedback_chips/#{group_chip.id}", data_to_post

    assert_equal 200, last_response.status

    group_chip.reload
    assert_equal 'Feedback::FeedbackGroupChip', group_chip.type
  end

  def test_get_global_context_chips
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil)
    feedback_group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    feedback_template_chip = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: feedback_group_chip.id)
    learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: nil, context_type: nil)
    feedback_group_chip2 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome2.id)
    feedback_template_chip2 = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome2.id, parent_chip_id: feedback_group_chip2.id)
    add_auth_header_for user: User.first
    get 'api/global/feedback_chips'

    global_chips = Feedback::FeedbackChip.global_chips
    chip_count = global_chips.count

    assert_equal 200, last_response.status
    assert_equal chip_count, last_response_body.count

    ids = global_chips.pluck(:id)
    last_response_body.each do |line|
      assert ids.include?(line['id'])
    end
  end
end
