require "test_helper"

class CampusTest < ActiveSupport::TestCase
  def test_create_campus
    data = {
      name: 'Burwood',
      mode: 'automatic',
      abbreviation: 'B'
    }

    campus = Campus.create!(data)
    assert campus.valid?
  end
end
