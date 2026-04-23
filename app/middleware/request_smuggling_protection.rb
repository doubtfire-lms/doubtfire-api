# frozen_string_literal: true

require 'json'

#
# Rejects ambiguous HTTP framing headers to reduce request smuggling risk.
#
class RequestSmugglingProtection
  BAD_REQUEST_RESPONSE = [
    400,
    { 'Content-Type' => 'application/json', 'Connection' => 'close' },
    [{ error: 'Malformed request framing headers' }.to_json]
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    return BAD_REQUEST_RESPONSE if malformed_framing_headers?(env)

    @app.call(env)
  end

  private

  def malformed_framing_headers?(env)
    content_length = env['CONTENT_LENGTH']
    transfer_encoding = env['HTTP_TRANSFER_ENCODING']

    conflicting_content_length_and_transfer_encoding?(content_length, transfer_encoding) ||
      invalid_content_length?(content_length) ||
      invalid_transfer_encoding?(transfer_encoding)
  end

  def conflicting_content_length_and_transfer_encoding?(content_length, transfer_encoding)
    header_present?(content_length) && header_present?(transfer_encoding)
  end

  def invalid_content_length?(content_length)
    return false unless header_present?(content_length)

    content_length.include?(',') || content_length !~ /\A\d+\z/
  end

  def invalid_transfer_encoding?(transfer_encoding)
    return false unless header_present?(transfer_encoding)

    normalized = transfer_encoding.split(',').map(&:strip).reject(&:empty?)
    normalized != ['chunked']
  end

  def header_present?(value)
    !value.nil? && !value.strip.empty?
  end
end
