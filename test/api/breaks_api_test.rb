require 'test_helper'

class BreaksApiTest < ActiveSupport::TestCase
include Rack::Test::Methods
include TestHelpers::AuthHelper
include TestHelpers::JsonHelper

def app
    Rails.application
end

end