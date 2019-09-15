require 'test_helper'
class LearningOutcomeTest < ActiveSupport::TestCase

  def setup
    data = {
        code: 'COS10002',
        name: 'Testing in Unit Tests',
        description: 'Test unit',
        teaching_period: TeachingPeriod.find(3)
      }
    @unit = Unit.create(data)
 end

  # Check abbreviation uniqueness
  def test_create_learning_outcome_with_not_unique_abbrev  
    learning_outcome_count = LearningOutcome.count	
    LearningOutcome.create!(
      unit_id: @unit.id,
      name: 'Functional Decomposition',
      description: 'desc',
      abbreviation: 'DECOMP',
      ilo_number: learning_outcome_count+1
    )
	learning_outcome_count = LearningOutcome.count

  assert_raises ActiveRecord::RecordInvalid do
      learning_outcome = LearningOutcome.create!(
      unit_id: @unit.id,
      name: 'Program',
      description: 'desc',
      abbreviation: 'DECOMP',
      ilo_number: learning_outcome_count+1
    )  
    end 
  end
end