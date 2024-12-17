require 'test_helper'

class FeedbackTemplateChipApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_default_create
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    assert template_chip.valid?
  ensure
    learning_outcome.destroy
    group_chip.destroy
    template_chip.destroy
  end

  def test_specific_create
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'Sample chip text', description: 'Sample description', comment_text: 'Sample comment text', summary_text: 'Sample summary text', task_status_id: TaskStatus.complete.id, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    assert_equal template_chip.chip_text, 'Sample chip text'
    assert_equal template_chip.description, 'Sample description'
    assert_equal template_chip.comment_text, 'Sample comment text'
    assert_equal template_chip.summary_text, 'Sample summary text'
    assert_equal template_chip.task_status_id, TaskStatus.complete.id
    assert_equal template_chip.learning_outcome_id, learning_outcome.id
    assert_equal template_chip.parent_chip_id, group_chip.id
    assert template_chip.valid?
  ensure
    learning_outcome.destroy
    group_chip.destroy
    template_chip.destroy
  end

  def test_get_feedback_chip_by_context
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'test1', short_description: 'sd', full_outcome_description: 'fod')
    learning_outcome2 = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', abbreviation: 'test2', short_description: 'sd', full_outcome_description: 'fod')
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    group_chip2 = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome2.id)
    template_chip1 = FactoryBot.create(:feedback_template_chip, chip_text: 'testing 1', learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    template_chip2 = FactoryBot.create(:feedback_template_chip, chip_text: 'testing 2', learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    template_chip3 = FactoryBot.create(:feedback_template_chip, chip_text: 'testing 3', learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    template_chip11 = FactoryBot.create(:feedback_template_chip, chip_text: 'testing 11', learning_outcome_id: learning_outcome2.id, parent_chip_id: group_chip2.id)
    template_chip12 = FactoryBot.create(:feedback_template_chip, chip_text: 'testing 12', learning_outcome_id: learning_outcome2.id, parent_chip_id: group_chip2.id)
    template_chip13 = FactoryBot.create(:feedback_template_chip, chip_text: 'testing 13', learning_outcome_id: learning_outcome2.id, parent_chip_id: group_chip2.id)
    add_auth_header_for user: User.first
    get "api/feedback_template_chips/context/Unit/#{unit.id}"
    assert_equal 200, last_response.status
  ensure
    unit.destroy
    learning_outcome.destroy
    learning_outcome2.destroy
    group_chip.destroy
    group_chip2.destroy
    template_chip1.destroy
    template_chip2.destroy
    template_chip3.destroy
    template_chip11.destroy
    template_chip12.destroy
    template_chip13.destroy
  end

  def test_create_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    data_to_post = {
      chip_text: 'Sample chip text',
      description: 'Sample description',
      task_status_id: TaskStatus.complete.id,
      parent_chip_id: group_chip.id,
      learning_outcome_id: learning_outcome.id,
      comment_text: 'Sample comment text',
      summary_text: 'Sample summary text'
    }
    add_auth_header_for user: User.first
    post_json 'api/feedback_template_chips', data_to_post
    assert_equal 201, last_response.status
  ensure
    group_chip.destroy
    learning_outcome.destroy
  end

  def test_get_all_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    add_auth_header_for user: User.first
    get "api/feedback_template_chips"
    assert_equal 200, last_response.status
  ensure
    learning_outcome.destroy
    group_chip.destroy
    template_chip.destroy
  end

  def test_get_specific_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'chippy', description: 'blah blah', comment_text: 'your work is horrible', summary_text: 'just plain bad', task_status_id: TaskStatus.complete.id, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    add_auth_header_for user: User.first
    get "api/feedback_template_chips/#{template_chip.id}"
    assert_equal 200, last_response.status
  ensure
    learning_outcome.destroy
    group_chip.destroy
    template_chip.destroy
  end

  def test_update_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'chippy', description: 'blah blah', comment_text: 'your work is horrible', summary_text: 'just plain bad', task_status_id: TaskStatus.complete.id, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    data_to_post = {
      chip_text: 'Sample chip text',
      description: 'Sample description',
      task_status_id: TaskStatus.complete.id,
      parent_chip_id: nil,
      learning_outcome_id: 1,
      comment_text: 'Sample comment text',
      summary_text: 'Sample summary text'
    }
    add_auth_header_for user: User.first
    put_json "api/feedback_template_chips/#{template_chip.id}", data_to_post
    assert_equal 200, last_response.status
  ensure
    learning_outcome.destroy
    group_chip.destroy
    template_chip.destroy
  end

  def test_delete_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    template_chip = FactoryBot.create(:feedback_template_chip, learning_outcome_id: learning_outcome.id, parent_chip_id: group_chip.id)
    add_auth_header_for user: User.first
    delete "api/feedback_template_chips/#{template_chip.id}"
    assert_equal 204, last_response.status
  ensure
    learning_outcome.destroy
    group_chip.destroy
  end

  def test_unauthorised_create_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    data_to_post = {
      chip_text: 'Sample chip text',
      description: 'Sample description',
      task_status_id: TaskStatus.complete.id,
      parent_chip_id: group_chip.id,
      learning_outcome_id: learning_outcome.id,
      comment_text: 'Sample comment text',
      summary_text: 'Sample summary text'
    }
    post_json 'api/feedback_template_chips', data_to_post
    assert_equal 419, last_response.status
  ensure
    learning_outcome.destroy
    group_chip.destroy
  end

  def test_wrong_auth_level_create_feedback_template_chip
    learning_outcome = FactoryBot.create(:learning_outcome)
    group_chip = FactoryBot.create(:feedback_group_chip, learning_outcome_id: learning_outcome.id)
    data_to_post = {
      chip_text: 'Sample chip text',
      description: 'Sample description',
      task_status_id: TaskStatus.complete.id,
      parent_chip_id: group_chip.id,
      learning_outcome_id: learning_outcome.id,
      comment_text: 'Sample comment text',
      summary_text: 'Sample summary text'
    }
    add_auth_header_for user: User.last
    post_json 'api/feedback_template_chips', data_to_post
    assert_equal 403, last_response.status
  ensure
    learning_outcome.destroy
    group_chip.destroy
  end
end
