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
    template_chip = FactoryBot.create(:feedback_template_chip, abbreviation: 'Sample abbreviation', order: 1, chip_text: 'Sample chip text', description: 'Sample description', comment_text: 'Sample comment text', summary_text: 'Sample summary text', task_status: 'In Progress')
    assert_equal template_chip.abbreviation, 'Sample abbreviation'
    assert_equal template_chip.order, 1
    assert_equal template_chip.chip_text, 'Sample chip text'
    assert_equal template_chip.description, 'Sample description'
    assert_equal template_chip.comment_text, 'Sample comment text'
    assert_equal template_chip.summary_text, 'Sample summary text'
    assert_equal template_chip.task_status, 'In Progress'
    assert template_chip.valid?
    template_chip.destroy
  end

  def test_create_feedback_template_chip
    data_to_post = {
      abbreviation: 'Sample abbreviation',
      order: 1,
      chip_text: 'Sample chip text',
      description: 'Sample description',
      comment_text: 'Sample comment text',
      summary_text: 'Sample summary text',
      task_status: 'In Progress'
    }

    add_auth_header_for user: User.first
    post_json 'api/feedback_template_chips', data_to_post
    assert_equal 201, last_response.status
  end

end
