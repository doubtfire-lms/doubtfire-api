require 'test_helper'

class FeedbackTemplateChipApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_default_create
    template_chip = FactoryBot.create(:feedback_template_chip)
    assert template_chip.valid?
    template_chip.destroy
  end

  def test_specific_create
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'Sample chip text', description: 'Sample description', comment_text: 'Sample comment text', summary_text: 'Sample summary text', task_status_id: TaskStatus.complete.id)
    assert_equal template_chip.chip_text, 'Sample chip text'
    assert_equal template_chip.description, 'Sample description'
    assert_equal template_chip.comment_text, 'Sample comment text'
    assert_equal template_chip.summary_text, 'Sample summary text'
    assert_equal template_chip.task_status_id, TaskStatus.complete.id
    assert template_chip.valid?
    template_chip.destroy
  end

  def test_create_feedback_template_chip
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
    post_json 'api/feedback_template_chips', data_to_post
    assert_equal 201, last_response.status
  end

  def test_get_all_feedback_template_chip
    template_chip = FactoryBot.create(:feedback_template_chip)
    add_auth_header_for user: User.first
    get "api/feedback_template_chips"
    assert_equal 200, last_response.status
    template_chip.destroy
  end

  def test_get_specific_feedback_template_chip
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'chippy', description: 'blah blah', comment_text: 'your work is horrible', summary_text: 'just plain bad', task_status_id: TaskStatus.complete.id)
    add_auth_header_for user: User.first
    get "api/feedback_template_chips/#{template_chip.id}"
    assert_equal 200, last_response.status
    template_chip.destroy
  end

  def test_update_feedback_template_chip
    template_chip = FactoryBot.create(:feedback_template_chip, chip_text: 'chippy', description: 'blah blah', comment_text: 'your work is horrible', summary_text: 'just plain bad', task_status_id: TaskStatus.complete.id)
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
    template_chip.destroy
  end

  def test_delete_feedback_template_chip
    template_chip = FactoryBot.create(:feedback_template_chip)
    add_auth_header_for user: User.first
    delete "api/feedback_template_chips/#{template_chip.id}"
    assert_equal 204, last_response.status
  end

  def test_unauthorised_create_feedback_template_chip
    data_to_post = {
      chip_text: 'Sample chip text',
      description: 'Sample description',
      task_status_id: TaskStatus.complete.id,
      parent_chip_id: nil,
      learning_outcome_id: 1,
      comment_text: 'Sample comment text',
      summary_text: 'Sample summary text'
    }
    post_json 'api/feedback_template_chips', data_to_post
    assert_equal 419, last_response.status
  end

  def test_wrong_auth_level_create_feedback_template_chip
    data_to_post = {
      chip_text: 'Sample chip text',
      description: 'Sample description',
      task_status_id: TaskStatus.complete.id,
      parent_chip_id: nil,
      learning_outcome_id: 1,
      comment_text: 'Sample comment text',
      summary_text: 'Sample summary text'
    }
    add_auth_header_for user: User.last
    post_json 'api/feedback_template_chips', data_to_post
    assert_equal 403, last_response.status
  end
end
