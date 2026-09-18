require 'test_helper'

class UriCredentialLeakMitigationTest < ActiveSupport::TestCase
  test 'strips credentials when merging a relative URI object' do
    base = URI.parse('https://user:password@internal.example/service')

    assert_equal 'https://internal.example/next', (base + URI.parse('/next')).to_s
  end

  test 'strips credentials when merging a relative string' do
    base = URI.parse('https://user:password@internal.example/service')

    assert_equal 'https://internal.example/next', base.public_send(:+, '/next').to_s
  end

  test 'does not alter absolute URI merges' do
    base = URI.parse('https://user:password@internal.example/service')

    assert_equal 'https://other:secret@external.example/next',
                 (base + URI.parse('https://other:secret@external.example/next')).to_s
  end
end
