require 'test_helper'

#
# Contains tests for LearningOutcomeTaskLink model objects - not accessed via API
#
class LearningOutcomeTaskLinkTest < ActiveSupport::TestCase

  def test_should_create_link_between_task_def_and_outcome
    unit = FactoryBot.create(:unit, with_students: false)

    task_def = unit.task_definitions.first
    lo = unit.learning_outcomes.first

    params = {
      task_definition_id: task_def.id,
      learning_outcome_id: lo.id,
      task_id: nil,
      rating: 3
    }

    link = LearningOutcomeTaskLink.create(params)

    assert_includes task_def.learning_outcome_task_links, link
    assert_includes task_def.learning_outcomes, lo

    assert_includes lo.learning_outcome_task_links, link
    assert_includes lo.related_task_definitions, task_def
  end

  def test_should_ensure_link_between_task_def_outcome_and_task_is_unique
    unit = FactoryBot.create(:unit, with_students: false)

    task_def = unit.task_definitions.first
    lo = unit.learning_outcomes.first

    params = {
      task_definition_id: task_def.id,
      learning_outcome_id: lo.id,
      task_id: nil,
      rating: 3
    }

    link1 = LearningOutcomeTaskLink.create!(params)

    assert_raises(ActiveRecord::RecordInvalid) {
      link2 = LearningOutcomeTaskLink.create!(params)
    }
  end

  def test_should_allow_multiple_outcome_td_links_when_tasks_included
    unit = FactoryBot.create(:unit, student_count: 1)

    task = unit.projects.first.task_for_task_definition(unit.task_definitions.first)
    task_def = task.task_definition
    lo = unit.learning_outcomes.first

    # Create link for unit
    params = {
      task_definition_id: task_def.id,
      learning_outcome_id: lo.id,
      task_id: nil,
      rating: 3
    }

    link1 = LearningOutcomeTaskLink.create!(params)

    # Create link for student/project
    params[:task_id] = task.id

    link2 = LearningOutcomeTaskLink.create!(params)

    assert_includes task_def.learning_outcome_task_links, link1
    assert_includes task_def.learning_outcomes, lo

    assert_includes task.learning_outcome_task_links, link2
    assert_includes task.learning_outcomes, lo
  end

  def test_rating_should_be_1_to_5
    unit = FactoryBot.create(:unit, student_count: 1)

    task_def = unit.task_definitions.first
    lo = unit.learning_outcomes.first

    # Create link for unit
    params = {
      task_definition_id: task_def.id,
      learning_outcome_id: lo.id,
      task_id: nil,
      rating: 0
    }

    assert_raises(ActiveRecord::RecordInvalid) {
      LearningOutcomeTaskLink.create!(params)
    }

    task = unit.projects.first.task_for_task_definition(unit.task_definitions.first)
    params[:task_id] = task.id
    assert_raises(ActiveRecord::RecordInvalid) {
      LearningOutcomeTaskLink.create!(params)
    }

    params[:rating] = 6
    assert_raises(ActiveRecord::RecordInvalid) {
      LearningOutcomeTaskLink.create!(params)
    }

    task = unit.projects.first.task_for_task_definition(unit.task_definitions.first)
    params[:task_id] = task.id
    assert_raises(ActiveRecord::RecordInvalid) {
      LearningOutcomeTaskLink.create!(params)
    }
  end
end
