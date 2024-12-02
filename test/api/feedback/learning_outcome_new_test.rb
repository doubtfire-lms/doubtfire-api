require 'test_helper'

class LearningOutcomeNewTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper

  def app
    Rails.application
  end

  def test_default_create
    learning_outcome = FactoryBot.create(:learning_outcome)
    assert learning_outcome.valid?
  end

  def test_specific_create
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    data_to_post = {
      context_type: 'Unit',
      context_id: unit.id,
      name: 'name',
      description: 'description',
      tag: 'tag',
      ilo_number: 1
    }
    add_auth_header_for user: User.first
    post_json "api/units/#{unit.id}/outcomes", data_to_post
    assert_equal 201, last_response.status
    unit.destroy
  end

  def test_update_outcome
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', name: 'name', description: 'description', tag: 'tag', ilo_number: 1)
    data_to_put = {
      name: 'changed name',
      description: 'changed description',
      tag: 'changed tag',
      ilo_number: 2
    }
    add_auth_header_for user: User.first
    put_json "api/units/#{unit.id}/outcomes/#{learning_outcome.id}", data_to_put
    assert_equal 200, last_response.status
    unit.destroy
    learning_outcome.destroy
  end

  def test_delete_outcome
    unit = FactoryBot.create(:unit, name: 'i like units', code: 'abcde', description: 'test unit')
    learning_outcome = FactoryBot.create(:learning_outcome, context_id: unit.id, context_type: 'Unit', name: 'name', description: 'description', tag: 'tag', ilo_number: 1)
    add_auth_header_for user: User.first
    delete "api/units/#{unit.id}/outcomes/#{learning_outcome.id}"
    assert_equal 204, last_response.status
    unit.destroy
  end

end
