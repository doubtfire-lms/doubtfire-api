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
        expected_product_name =  Doubtfire::Application.config.institution[:product_name]
        
        # Perform the GET
        get '/api/settings'

        # Set returned details
        returned_mes = last_response_body['externalName']

        # Check if the call succeeds
        assert_equal 200, last_response.status
        # Check returned details match as expected 
        assert_equal expected_product_name, returned_mes
    end     

    # Get privacy policy details
    def test_get_privacy_policy_details
        expected_privacy = Doubtfire::Application.config.institution[:privacy]
        expected_plagiarism = Doubtfire::Application.config.institution[:plagiarism]
        
        # Perform the GET
        get '/api/settings/privacy'
        
        # Set two returned details
        returned_privacy = last_response_body['privacy']
        returned_plagiarism = last_response_body['plagiarism']

        # Check if the call succeeds
        assert_equal 200, last_response.status

        # Check returned details match as expected
        assert_equal expected_privacy, returned_privacy
        assert_equal expected_plagiarism, returned_plagiarism
    end
end
