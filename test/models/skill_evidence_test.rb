require 'test_helper'

class SkillEvidenceTest < ActiveSupport::TestCase
  def setup
    project = FactoryBot.create(:project)
    @task = project.task_for_task_definition(project.unit.task_definitions.first)
    @skill = Skill.create!(
      skill_framework: SkillFramework.create!(code: 'SFIA', name: 'SFIA', version: '9'),
      code: 'PROG',
      name: 'Programming'
    )
    @level_one = SkillLevel.create!(skill: @skill, name: 'Level 1', rank: 1)
    @level_two = SkillLevel.create!(skill: @skill, name: 'Level 2', rank: 2)
    @mapping = TaskDefinitionSkillMapping.create!(
      task_definition: @task.task_definition,
      skill: @skill,
      skill_level: @level_one
    )
  end

  def test_resubmission_keeps_the_previous_skill_claim_and_uses_the_new_mapping
    @task.record_skill_evidence!
    first = @task.skill_evidences.current.sole

    @mapping.update!(skill_level: @level_two)
    @task.record_skill_evidence!

    assert first.reload.superseded_at
    assert_equal @level_one, first.skill_level
    assert_equal @level_two, @task.skill_evidences.current.sole.skill_level
    assert_equal 2, @task.skill_evidences.count
  end

  def test_completion_endorses_the_submitted_snapshot_even_after_mapping_changes
    @task.record_skill_evidence!
    @mapping.update!(skill_level: @level_two)

    @task.update!(task_status: TaskStatus.complete)

    evidence = @task.skill_evidences.current.sole
    assert_equal @level_one, evidence.skill_level
    assert evidence.endorsed_at
  end

  def test_resubmission_also_supersedes_archived_evidence
    @task.record_skill_evidence!
    archived = @task.skill_evidences.sole
    archived.update!(archived_at: Time.zone.now)

    @task.record_skill_evidence!

    assert archived.reload.superseded_at
    assert_equal 1, @task.skill_evidences.current.count
  end
end
