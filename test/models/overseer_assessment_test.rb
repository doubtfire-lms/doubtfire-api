require "test_helper"

class OverseerAssessmentTest < ActiveSupport::TestCase
  def overseer_assessment
    @overseer_assessment ||= OverseerAssessment.new
  end

  def test_valid
    assert overseer_assessment.valid?
  end
end
