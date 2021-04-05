require 'test_helper'

module TestHelpers
  #
  # JSON Helpers
  #
  module JsonHelper
    module_function

    #
    # POSTs a hash data as JSON with content-type "application/json"
    #
    def post_json(endpoint, data)
      header 'CONTENT_TYPE', 'application/json'
      post URI.encode(endpoint), data.to_json
    end

    #
    # PUTs a hash data as JSON with content-type "application/json"
    #
    def put_json(endpoint, data)
      put URI.encode(endpoint), data.to_json, 'CONTENT_TYPE' => 'application/json'
    end

    #
    # PUTs a hash data as JSON with content-type "application/json"
    #
    def delete_json(endpoint)
      header 'CONTENT_TYPE', 'application/json'
      delete URI.encode(endpoint)
    end

    #
    # Assert that a JSON response matches the model and keys provided
    #
    def assert_json_matches_model(model, response_json, keys)
      keys.each { |k| assert response_json.key?(k), "Response missing key #{k} - #{response_json}" }
      keys.each { |k| 
        value = model.send(k)
        if ! value.nil?
          assert_equal value, response_json[k], "Values for key #{k} do not match - #{response_json}"
        else
          assert_nil response_json[k], "Values for key #{k} is not nil - #{response_json}"
        end
      }
    end

    #
    # Last response body parsed from JSON
    #
    def last_response_body
      JSON.parse(last_response.body)
    end

    #
    # Converts from an ActiveRelation to JSON (without Ruby objects inside the hash)
    #
    def json_hashed(hash)
      JSON.parse(hash.to_json)
    end

    #
    # Assert that the lefthand matches the right-hand as json hash
    #
    def assert_json_equal(lhs, rhs)
      assert_equal json_hashed(lhs), json_hashed(rhs)
    end
  end
end
