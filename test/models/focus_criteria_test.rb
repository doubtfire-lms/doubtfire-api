require "test_helper"

class FocusCriteriaTest < ActiveSupport::TestCase
  def test_focus_criterion
    # can add criteria to a focus
    f = FactoryBot.create(:focus, with_criteria: :none)

    assert_equal 0, f.focus_criteria.count

    f.set_criteria(GradeHelper::PASS_VALUE, "Criterion to pass")
    assert_equal 1, f.focus_criteria.count

    f.set_criteria(GradeHelper::CREDIT_VALUE, "Criterion for credit")
    assert_equal 2, f.focus_criteria.count

    f.set_criteria(GradeHelper::DISTINCTION_VALUE, "Criterion for distinction")
    assert_equal 3, f.focus_criteria.count

    f.set_criteria(GradeHelper::HD_VALUE, "Criterion for HD")
    assert_equal 4, f.focus_criteria.count
  end

  def test_limit_criteria_to_grade
    # can add criteria to a focus
    f = FactoryBot.create(:focus, with_criteria: :none)

    assert_equal 0, f.focus_criteria.count
    count = 0

    GradeHelper::RANGE.each do |grade|
      fc = f.set_criteria(grade, "Criterion to get the grade")
      count += 1
      assert_equal count, f.focus_criteria.count

      assert_equal "Criterion to get the grade", fc.description

      fc = f.set_criteria(grade, "Updated criterion")
      assert_equal count, f.focus_criteria.count

      assert_equal "Updated criterion", fc.description
    end

    # test cannot force create this...
    fc = FocusCriterion.create(focus: f, grade: GradeHelper::PASS_VALUE, description: "Manual create")
    refute fc.valid?
    assert_equal count, f.focus_criteria.count
  end


end
