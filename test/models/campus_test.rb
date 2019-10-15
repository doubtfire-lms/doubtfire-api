require "test_helper"

class CampusTest < ActiveSupport::TestCase
  def test_create_campus
    data = {
      name: 'Sydney',
      mode: 'automatic',
      abbreviation: 'Syd'
    }

    campus = Campus.create!(data)
    assert campus.valid?
  end
end
