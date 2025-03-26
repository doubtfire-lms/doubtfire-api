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

      post URI::Parser.new.escape(endpoint), data.to_json
    end

    #
    # PUTs a hash data as JSON with content-type "application/json"
    #
    def put_json(endpoint, data)
      put URI::Parser.new.escape(endpoint), data.to_json, 'CONTENT_TYPE' => 'application/json'
    end

    #
    # PUTs a hash data as JSON with content-type "application/json"
    #
    def delete_json(endpoint)
      header 'CONTENT_TYPE', 'application/json'
      delete URI::Parser.new.escape(endpoint)
    end

    #
    # Assert that a JSON response matches the model and keys provided
    # - key data is either a hash that maps response to model keys, or a list of keys to match
    def assert_json_matches_model(model, response_json, keys_data)
      if keys_data.instance_of? Hash
        response_keys = keys_data.keys.map(&:to_s)
        keys = keys_data
      else
        response_keys = keys_data
        keys = keys_data.to_h { |i| [i, i] }
      end
      response_keys.each do |k|
        assert response_json.key?(k) || response_json.key?(k.to_sym), "Response missing key #{k} - #{response_json}"
        mk = keys[k] || keys[k.to_sym]
        value = if model.is_a?(Hash)
                  model[mk].nil? ? model[mk.to_sym] : model[mk]
                else
                  model.send(mk)
                end
        model_value = response_json.key?(k) ? response_json[k] : response_json[k.to_sym]
        if value.nil?
          assert_nil model_value, "Values for key #{k} is not nil - #{response_json}"
        else
          assert_equal value, model_value, "Values for model key #{mk} does not match value of response key #{k} - #{response_json}"
        end
      end
    end

    def assert_json_limit_keys_to(keys, response_json)
      response_json.each_key do |k|
        assert keys.include?(k), "Unexpected key in response: #{k} -- #{response_json.inspect}"
      end
    end

    def assert_json_limit_keys_to_exactly(keys, response_json)
      assert_equal keys.count, response_json.keys.count, "Incorrect number of keys: #{response_json.inspect}"
      assert_json_limit_keys_to keys, response_json
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
