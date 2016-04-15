module AssertHelper

  def assert_json_matches_model(json, model, keys)
    keys.each { |k| assert json.has_key?(k), "Response has key #{k}"}
    keys.each { |k| assert_equal model[k], json[k], "Values for key #{k} match" }
  end

  module_function :assert_json_matches_model
end
