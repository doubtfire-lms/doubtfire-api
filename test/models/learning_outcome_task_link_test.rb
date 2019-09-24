require 'test_helper'
class LearningOutcomeTaskLinkTest < ActiveSupport::TestCase
def setup
    data = {
        code: 'COS10002',
        name: 'Testing in Unit Tests',
        description: 'Test unit',
        teaching_period: TeachingPeriod.find(3)
      }
    @unit = Unit.create(data)
end

def test_duplicate_to

	u = Unit.first
    lOL = u.learning_outcome_task_links.first
    
    learning_outcome_count = LearningOutcome.count

    LearningOutcome.create!(
    unit_id: @unit.id,
    name: 'Name',
    description: 'desc',
    abbreviation: 'PROG',
    ilo_number: learning_outcome_count+1
    )

    td = TaskDefinition.new({
      unit_id: @unit.id,
      name: 'Name',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: @unit.start_date + 1.week,
      target_date: @unit.start_date + 2.weeks,
      abbreviation: '1.1P',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      max_quality_pts: 5
    })

    td.save!
    
    lOL.duplicate_to(@unit) 
    assert @unit    
end	

def test_export_task_alignment_to_csv
  u = Unit.first
  assert LearningOutcomeTaskLink.export_task_alignment_to_csv(u,u)
end  

def test_ensure_relations_unique
  u = Unit.first
  lOL = u.learning_outcome_task_links.first
  assert_equal lOL.ensure_relations_unique, nil
end  
end