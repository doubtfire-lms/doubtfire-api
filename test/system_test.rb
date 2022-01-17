require "test_helper"

class SystemTest < ActiveSupport::TestCase
  def test_zeitwerk_is_loading_all_files
    Rails.application.eager_load!
    assert true
  end
end
