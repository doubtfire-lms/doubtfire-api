require "test_helper"

class FocusTest < ActiveSupport::TestCase
  def test_focus_factory
    f = FactoryBot.create(:focus)
    assert_not_nil f
    assert f.valid?
  end

  def test_unit_has_focuses
    u = FactoryBot.create(:unit, focus_count: 3)
    assert_equal 3, u.focuses.count
  end

end
