require 'test_helper'

class FeedbackChipApiTestCondolidated < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
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
    add_auth_header_for user: User.first
    post_json 'api/feedback_chips', data_to_post
    assert_equal 201, last_response.status
  end

  def test_create_feedback_template_chip
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
    post_json 'api/feedback_chips', data_to_post
    assert_equal 201, last_response.status
  end

  def test_get_all_feedback_chips_for_a_context
    unit = Unit.first
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
  end

  def test_update_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'chippy', description: 'blah blah', comment_text: 'your work is horrible', summary_text: 'just plain bad', task_status: TaskStatus.complete.name, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    data_to_post = {
      type: 'template',
      chip_text: 'Sample chip text',
      description: 'Sample description'
    }
    add_auth_header_for user: User.first
    put_json "api/feedback_chips/#{template_chip.id}", data_to_post
    assert_equal 200, last_response.status
  end

  def test_update_feedback_group_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    data_to_post = {
      type: 'group',
      chip_text: 'Sample chip text',
      description: 'Sample description'
    }
    add_auth_header_for user: User.first
    put_json "api/feedback_chips/#{group_chip.id}", data_to_post
    assert_equal 200, last_response.status
  end

  def test_delete_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'chippy', description: 'blah blah', comment_text: 'your work is horrible', summary_text: 'just plain bad', task_status: TaskStatus.complete.name, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    add_auth_header_for user: User.first
    delete "api/feedback_chips/#{template_chip.id}"
    assert_equal 204, last_response.status
  end

  def test_delete_feedback_group_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    add_auth_header_for user: User.first
    delete "api/feedback_chips/#{group_chip.id}"
    assert_equal 204, last_response.status
  end
end
