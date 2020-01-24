require 'test_helper'
require 'user'

class GroupSetsApiTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include TestHelpers::AuthHelper
  include TestHelpers::JsonHelper
  include TestHelpers::TestFileHelper

  def app
    Rails.application
  end

  def test_get_all_groups_in_unit_with_authorization
    # Create unit
    newUnit = FactoryBot.create(:unit)
  
    get with_auth_token "/api/units/#{newUnit.id}/groups",newUnit.main_convenor_user
    assert_equal 200, last_response.status
  end  

  def test_get_all_groups_in_unit_without_authorization
    # Create unit
    newUnit = FactoryBot.create(:unit)
    # Create student
    studentUser = FactoryBot.create(:user, :student)

    get with_auth_token "/api/units/#{newUnit.id}/groups",studentUser
    assert_equal 403, last_response.status
  end  

end
