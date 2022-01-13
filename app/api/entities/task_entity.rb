module Entities
  class TaskEntity < Grape::Entity
    expose :id
    expose :project_id
    expose :task_definition_id

    expose :status

    expose :due_date
    expose :extensions

    expose :submission_date
    expose :completion_date

    expose :times_assessed
    expose :grade
    expose :quality_pts

    expose :include_in_portfolio

    # Attributes excluded from update only

    expose :pct_similar, unless: :update_only
    expose :similar_to_count, unless: :update_only
    expose :similar_to_dismissed_count, unless: :update_only

    expose :num_new_comments, unless: :update_only

    # Attributes only included in "update only"

    expose :new_stats, if: :update_only do |task, options|
      task.project.task_stats
    end

    # Attributes only included if include other projects

    expose :other_projects, if: :include_other_projects do |task, options|
      if task.group_task? && !task.group.nil?
        grp = task.group
        grp.projects.select { |p| p.id != task.project_id }.map { |p| { id: p.id, new_stats: p.task_stats } }
      end
    end
  end
end
