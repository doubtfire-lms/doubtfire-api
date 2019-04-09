require 'test_helper'

#
# Contains tests for TaskDefinition model objects - not accessed via API
#
class TaskDefinitionTest < ActiveSupport::TestCase
  def app
    Rails.application
  end

  def test_default_quality_points
    test_unit = Unit.first
    td = TaskDefinition.new({
      unit_id: test_unit.id,
      name: 'Test quality points',
      description: 'test def',
      weighting: 4,
      target_grade: 0,
      start_date: test_unit.start_date + 1.week,
      target_date: test_unit.start_date + 2.weeks,
      abbreviation: 'TestQualPts',
      restrict_status_updates: false,
      upload_requirements: [ ],
      plagiarism_warn_pct: 0.8,
      is_graded: false,
      max_quality_pts: 5
    })
    td.save!

    p = test_unit.active_projects.first

    task = p.task_for_task_definition(td)

    assert task
    assert task.quality_pts = -1

    td.destroy
  end

  def test_default_quality_points
    u = Unit.first

    group_params = {
      name: 'Group Work',
      allow_students_to_create_groups: true,
      allow_students_to_manage_groups: true,
      keep_groups_in_same_class: true
    }

    initial_count = u.task_definitions.count

    group_set = GroupSet.create!(group_params)
    group_set.unit = u
    group_set.save!

    path = Rails.root.join('test_files', 'unit_csv_imports', 'import_group_tasks.csv')
    u.import_tasks_from_csv File.new(path)

    assert_equal 1, group_set.task_definitions.count
    assert_equal initial_count + 1, u.task_definitions.count
  end
end
