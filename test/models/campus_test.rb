require "test_helper"

class CampusTest < ActiveSupport::TestCase

  # FactoryGirl.create will create campus from the values defined in the Campus factory
  # We can override the values as well, for specific test cases it is recommended that we do
  # FactoryGirl.create(:campus, name: 'Burwood')
  def test_default_create
    campus = FactoryGirl.create(:campus)
    assert campus.valid?
  end
end
