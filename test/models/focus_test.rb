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

  def test_can_get_focus_for_project
    u = FactoryBot.create(:unit, focus_count: 3, with_students: true)

    p = u.active_projects.first
    f = p.project_focus_for(u.focuses.first)

    assert f.valid?, f.errors.full_messages
    assert_equal 1, p.project_focuses.count
    assert_equal u.focuses.first, p.project_focuses.first.focus
  end

  def test_can_award_grade_to_focus_for_project
    u = FactoryBot.create(:unit, focus_count: 3, with_students: true)

    p = u.active_projects.first
    td = u.task_definitions.first
    t = p.task_for_task_definition td
    p.award_focus_grade u.focuses.first, GradeHelper::PASS_VALUE, t, p.tutor_for(td)
  end

  def test_endure_project_focus_match_unit
    u1 = FactoryBot.create(:unit, focus_count: 1, with_students: true)
    u2 = FactoryBot.create(:unit, focus_count: 1, with_students: false)

    p = u1.active_projects.first
    pf = p.project_focus_for(u2.focuses.first)

    refute pf.valid?
    assert_equal 0, p.project_focuses.count
  end

  def test_focus_color_range
    f = FactoryBot.build(:focus)
    assert_not_nil f
    assert f.valid?

    f.color = 15
    refute f.valid?

    f.color = -1
    refute f.valid?
  end
end
