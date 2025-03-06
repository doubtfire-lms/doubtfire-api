require 'test_helper'

module TestHelpers
  #
  # Turn It In Test Helpers
  #
  module OverseerTestHelper
    module_function

    def setup_overseer_enabled
      Doubtfire::Application.config.overseer_enabled = true
    end
  end
end
