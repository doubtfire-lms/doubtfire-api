require 'test_helper'

class UnitTest < ActiveSupport::TestCase
  
  test 'ensure valid response from unit ilo data' do
    unit = Unit.first
    details = unit.ilo_progress_class_details

    assert details.key?('all'), 'contains all key'

    unit.tutorials.each do |tute|
      assert details.key?(tute.id), 'contains tutorial keys'
    end

  end
end
