require 'test_helper'
require 'rack/mock'

class CorsTest < ActiveSupport::TestCase
  test 'normalizes configured institution hosts into origins' do
    assert_equal 'https://ontrack.example.edu', Doubtfire::Application.cors_origin_for('ontrack.example.edu')
    assert_equal 'https://ontrack.example.edu', Doubtfire::Application.cors_origin_for('https://ontrack.example.edu')
    assert_equal 'http://localhost:4200', Doubtfire::Application.cors_origin_for('http://localhost:4200')
  end

  test 'allows the frontend authentication headers and patch method' do
    response_headers = preflight(
      origin: 'http://localhost:4200',
      method: 'PATCH',
      headers: 'Auth-Token,Username,Content-Type'
    )

    assert_equal 'http://localhost:4200', response_headers['access-control-allow-origin']
    assert_includes response_headers['access-control-allow-methods'], 'PATCH'
    assert_equal 'Auth-Token,Username,Content-Type', response_headers['access-control-allow-headers']
  end

  test 'rejects origins outside the allowlist' do
    response_headers = preflight(
      origin: 'https://untrusted.example.edu',
      method: 'GET',
      headers: 'Authorization'
    )

    assert_nil response_headers['access-control-allow-origin']
  end

  private

  def preflight(origin:, method:, headers:)
    env = Rack::MockRequest.env_for(
      'http://www.example.com/api/settings',
      method: 'OPTIONS',
      'HTTP_ORIGIN' => origin,
      'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => method,
      'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => headers
    )

    _status, response_headers, = Rails.application.call(env)
    response_headers
  end
end
