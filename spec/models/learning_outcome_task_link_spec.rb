require 'rails_helper'

RSpec.describe LearningOutcomeTaskLink, type: :model do
  
  it "should allow you to create a link between task_def and lo" do
    unit = FactoryBot.create(:unit)

    task_def = unit.task_definitions.first
    lo = unit.learning_outcomes.first

    params = {
      task_definition_id: task_def.id,
      learning_outcome_id: lo.id,
      task_id: nil,
      rating: 3
    }

    link = LearningOutcomeTaskLink.create(params)

    expect(task_def.learning_outcome_task_links).to include(link)
    expect(task_def.learning_outcomes).to include(lo)

    expect(lo.learning_outcome_task_links).to include(link)
    expect(lo.related_task_definitions).to include(task_def)
  end

  it "should ensure the link between task_def, lo, task is unique" do
    unit = FactoryBot.create(:unit)

    task_def = unit.task_definitions.first
    lo = unit.learning_outcomes.first

    params = {
      task_definition_id: task_def.id,
      learning_outcome_id: lo.id,
      task_id: nil,
      rating: 3
    }

    link1 = LearningOutcomeTaskLink.create!(params)

    expect {
       link2 = LearningOutcomeTaskLink.create!(params)
    }.to raise_exception ActiveRecord::RecordInvalid
  end

  it "should allow multiple lo - td links when tasks included" do
    unit = FactoryBot.create(:unit, student_count: 1)

    task = unit.projects.first.tasks.first
    task_def = task.task_definition
    lo = unit.learning_outcomes.first

    params = {
      task_definition_id: task_def.id,
      learning_outcome_id: lo.id,
      task_id: nil,
      rating: 3
    }

    link1 = LearningOutcomeTaskLink.create!(params)

    params[:task_id] = task.id

    link2 = LearningOutcomeTaskLink.create!(params)

    expect(task_def.learning_outcome_task_links).to include(link1)
    expect(task_def.learning_outcomes).to include(lo)

    expect(task.learning_outcome_task_links).to include(link2)
    expect(task.learning_outcomes).to include(lo)
  end
end
