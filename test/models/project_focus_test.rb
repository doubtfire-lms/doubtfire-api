require "test_helper"

class FocusCommentTest < ActiveSupport::TestCase
  def test_can_get_focus_for_project
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true)

    p = u.active_projects.first
    project_focus = p.project_focus_for(u.focuses.first)

    assert project_focus.present?
    assert project_focus.valid?, project_focus.errors.full_messages
    assert_equal 1, p.project_focuses.count
    assert_equal u.focuses.first, p.project_focuses.first.focus

    refute project_focus.current
    refute project_focus.grade_achieved.present?
  end

  def test_endure_project_focus_match_unit
    u1 = FactoryBot.create(:unit, focus_count: 1, with_students: true)
    u2 = FactoryBot.create(:unit, focus_count: 1, with_students: false)

    p = u1.active_projects.first
    pf = p.project_focus_for(u2.focuses.first)

    refute pf.valid?
    assert_equal 0, p.project_focuses.count
  end

  def test_projects_focus_grade_range
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)

    p = u.active_projects.first
    t = p.task_for_task_definition u.task_definitions.first
    focus = u.focuses.first

    project_focus = p.project_focus_for(focus)

    assert project_focus.valid?

    project_focus.grade_achieved = GradeHelper::FAIL_VALUE - 1
    refute project_focus.valid?

    project_focus.grade_achieved = GradeHelper::HD_VALUE + 1
    refute project_focus.valid?
  end

  def test_can_award_focus
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)

    p = u.active_projects.first
    t = p.task_for_task_definition u.task_definitions.first
    focus = u.focuses.first
    pf = p.project_focus_for(focus)

    count = t.comments.count

    p.assess_focus focus, GradeHelper::PASS_VALUE, false, t, p.tutor_for(t.task_definition)

    pf.reload

    assert pf.valid?
    assert_equal GradeHelper::PASS_VALUE, pf.grade_achieved
    assert_equal count + 1, t.comments.count
  end

  def test_can_set_current_focus
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)

    p = u.active_projects.first
    t = p.task_for_task_definition u.task_definitions.first
    focus = u.focuses.first
    pf = p.project_focus_for(focus)

    count = t.comments.count

    pf.make_current p.student, t

    pf.reload

    assert pf.valid?
    assert pf.current
    assert_equal count + 1, t.comments.count
  end

  def test_can_move_on_from_focus
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)

    p = u.active_projects.first
    t = p.task_for_task_definition u.task_definitions.first
    focus = u.focuses.first
    pf = p.project_focus_for(focus)

    pf.update current: true

    count = t.comments.count

    pf.make_current p.student, t, false

    pf.reload

    assert pf.valid?
    refute pf.current
    assert_equal count + 1, t.comments.count
  end

  def test_comment_only_when_change_of_current
    u = FactoryBot.create(:unit, focus_count: 1, with_students: true, student_count: 1)

    p = u.active_projects.first
    t = p.task_for_task_definition u.task_definitions.first
    focus = u.focuses.first
    pf = p.project_focus_for(focus)

    count = t.comments.count

    pf.make_current p.student, t, false

    pf.reload

    assert pf.valid?
    refute pf.current
    assert_equal count, t.comments.count

    pf.update current: true
    pf.make_current p.student, t, true

    pf.reload

    assert pf.valid?
    assert pf.current
    assert_equal count, t.comments.count
  end

end
