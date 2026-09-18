# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

#
# Server-to-server client for the LTI service's internal API. Every request is keyed by an
# OnTrack unit id, so callers must authorise the user for that unit before using it.
#
class LtiServer
  class Error < StandardError
    attr_reader :status

    def initialize(message, status: 502)
      @status = status
      super(message)
    end
  end

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 120

  def self.configured?
    config = Doubtfire::Application.config
    config.lti_internal_url.present? && config.lti_internal_key.present?
  end

  def initialize(unit_id)
    @unit_id = Integer(unit_id)
  end

  # Returns nil when the unit is not linked to an LMS course.
  def link
    request(:get, 'link')
  rescue Error => e
    raise unless e.status == 404

    nil
  end

  def unlink
    request(:delete, 'link')
  end

  def members
    request(:get, 'members')
  end

  def course_data(include: nil, assignment_id: nil)
    body = {}
    body[:include] = include if include.present?
    body[:assignmentId] = assignment_id if assignment_id.present?
    request(:post, 'course-data', body)
  end

  def grade_line_item
    request(:get, 'grade-line-item')
  end

  def ensure_grade_line_item
    request(:post, 'grade-line-item')
  end

  def submit_scores(scores)
    request(:post, 'scores', { scores: scores })
  end

  private

  def request(method, path, body = nil)
    config = Doubtfire::Application.config
    unless LtiServer.configured?
      raise Error.new('The LTI service is not configured (LTI_INTERNAL_URL and LTI_INTERNAL_SYNC_KEY)', status: 503)
    end

    uri = URI.parse("#{config.lti_internal_url.sub(%r{/+\z}, '')}/lti/api/internal/units/#{@unit_id}/#{path}")
    request = case method
              when :get then Net::HTTP::Get.new(uri)
              when :post then Net::HTTP::Post.new(uri)
              when :delete then Net::HTTP::Delete.new(uri)
              end
    request['Accept'] = 'application/json'
    request['X-Internal-Key'] = config.lti_internal_key
    if body
      request['Content-Type'] = 'application/json'
      request.body = body.to_json
    end

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                                   open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.request(request)
    end

    payload = response.body.present? ? JSON.parse(response.body) : nil
    unless response.is_a?(Net::HTTPSuccess)
      message = payload.is_a?(Hash) && payload['error'].is_a?(String) ? payload['error'] : "The LTI service responded #{response.code}"
      raise Error.new(message, status: response.code.to_i)
    end

    payload
  rescue JSON::ParserError
    raise Error, 'The LTI service returned an invalid response'
  rescue URI::InvalidURIError
    raise Error.new('LTI_INTERNAL_URL is invalid', status: 503)
  rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
    raise Error.new("Unable to reach the LTI service: #{e.message}", status: 503)
  end
end
