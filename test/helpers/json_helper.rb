require 'test_helper'

module TestHelpers
  #
  # JSON Helpers
  #
  module JsonHelper
    #
    # POSTs a hash data as JSON with content-type "application/json"
    #
    def post_json(endpoint, data)
      post endpoint, data.to_json, 'CONTENT_TYPE' => 'application/json'
    end

    #
    # PUTs a hash data as JSON with content-type "application/json"
    #
    def put_json(endpoint, data)
      put endpoint, data.to_json, 'CONTENT_TYPE' => 'application/json'
    end

    #
    # Assert that a JSON response matches the model and keys provided
    #
    def assert_json_matches_model(response_json, model, keys)
      keys.each { |k| assert response_json.has_key?(k), "Response has key #{k}"}
      keys.each { |k| assert_equal model[k], response_json[k], "Values for key #{k} match" }
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

    module_function :assert_json_matches_model
    module_function :post_json
    module_function :put_json
    module_function :last_response_body
    module_function :json_hashed
    module_function :assert_json_equal
  end
end
