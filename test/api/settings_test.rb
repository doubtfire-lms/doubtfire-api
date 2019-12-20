require 'test_helper'
require 'json'

class SettingTest < ActiveSupport::TestCase
    include Rack::Test::Methods
    include TestHelpers::AuthHelper
    include TestHelpers::JsonHelper

    def app
        Rails.application
    end

    # Get config details
    def test_get_config_details        
        expected_ProductName =  Doubtfire::Application.config.institution[:product_name]
        
        # Perform the GET
        get '/api/settings'

        # Set returned details
        returned_mes = last_response_body['externalName']

        # Check if the call succeeds
        assert_equal 200, last_response.status
        # Check returned details match as expected 
        assert_equal expected_ProductName, returned_mes
    end     

end
