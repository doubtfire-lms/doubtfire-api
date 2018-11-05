require 'test_helper'

class TaskStatusTest < ActiveSupport::TestCase
  test 'ensure status matches id' do
    TaskStatus.all.each do |ts|
      assert_equal TaskStatus.id_to_key(ts.id), ts.status_key 
    end
  end
end
