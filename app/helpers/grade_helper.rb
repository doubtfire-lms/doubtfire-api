module GradeHelper
  def grade_for value
    case value
    when 0
      'Pass'
    when 1
      'Credit'
    when 2
      'Distinction'
    when 3
      'High Distinction'
    when nil
      nil
    else
      'Fail'
    end
  end

  def short_grade_for value
    case value
    when 0
      'P'
    when 1
      'C'
    when 2
      'D'
    when 3
      'HD'
    when nil
      nil
    else
      'F'
    end
  end

  module_function :grade_for
  module_function :short_grade_for
end
