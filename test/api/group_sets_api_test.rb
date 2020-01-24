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

  def test_get_all_groups_in_unit
    # Create unit
    newUnit = FactoryBot.create(:unit)
    # Create admin
    adminUser = FactoryBot.create(:user, :admin)  
    get with_auth_token "/unit/#{newUnit.id}/groups",adminUser
  end  

end
