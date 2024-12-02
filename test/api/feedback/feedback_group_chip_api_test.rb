require 'test_helper'

class FeedbackGroupChipApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_default_create
    group_chip = FactoryBot.create(:feedback_group_chip)
    assert group_chip.valid?
    group_chip.destroy
  end

  def test_specific_create
    group_chip = FactoryBot.create(:feedback_group_chip, chip_text: 'Sample chip_text', parent_chip_id: nil, learning_outcome_id: 1)
    assert_equal group_chip.chip_text, 'Sample chip_text'
    assert_equal group_chip.parent_chip_id, nil
    assert_equal group_chip.learning_outcome_id, 1
    assert group_chip.valid?
    group_chip.destroy
  end

  def test_create_feedback_group_chip
    data_to_post = {
      chip_text: 'Sample chip text',
      description: 'Sample description',
      parent_chip_id: nil,
      learning_outcome_id: 1,
    }
    add_auth_header_for user: User.first
    post_json 'api/feedback_group_chips', data_to_post
    assert_equal 201, last_response.status
  end

  def test_get_all_feedback_group_chip
    group_chip = FactoryBot.create(:feedback_group_chip)
    add_auth_header_for user: User.first
    get "api/feedback_group_chips"
    assert_equal 200, last_response.status
    group_chip.destroy
  end

  def test_get_specific_feedback_group_chip
    group_chip = FactoryBot.create(:feedback_group_chip, chip_text: 'Sample chip_text', parent_chip_id: nil, learning_outcome_id: 1)
    add_auth_header_for user: User.first
    get "api/feedback_group_chips/#{group_chip.id}"
    assert_equal 200, last_response.status
    group_chip.destroy
  end

  def test_update_feedback_group_chip
    group_chip = FactoryBot.create(:feedback_group_chip)
    data_to_post = {
      chip_text: 'Sample chip text',
      description: 'Sample description',
      parent_chip_id: nil,
      learning_outcome_id: 1,
    }
    add_auth_header_for user: User.first
    put_json "api/feedback_group_chips/#{group_chip.id}", data_to_post
    assert_equal 200, last_response.status
    group_chip.destroy
  end

  def test_delete_feedback_group_chip
    group_chip = FactoryBot.create(:feedback_group_chip)
    add_auth_header_for user: User.first
    delete "api/feedback_group_chips/#{group_chip.id}"
    assert_equal 204, last_response.status
  end

  def test_unauthorised_create_feedback_group_chip
    data_to_post = {
      chip_text: 'Sample chip text',
      description: 'Sample description',
      parent_chip_id: nil,
      learning_outcome_id: 1,
    }
    post_json 'api/feedback_group_chips', data_to_post
    assert_equal 419, last_response.status
  end

  def test_wrong_auth_level_create_feedback_group_chip
    data_to_post = {
      chip_text: 'Sample chip text',
      description: 'Sample description',
      parent_chip_id: nil,
      learning_outcome_id: 1,
    }
    add_auth_header_for user: User.last
    post_json 'api/feedback_group_chips', data_to_post
    assert_equal 403, last_response.status
  end
end
