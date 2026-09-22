require 'test_helper'

class LtiHelperTest < ActiveSupport::TestCase
  test 'only one of many concurrent uses of a token id succeeds' do
    jti = SecureRandom.uuid
    results = Array.new(8) { Thread.new { LtiHelper.first_use?(jti, 30) } }.map(&:value)

    assert_equal 1, results.count(true), results.inspect
  end
end
