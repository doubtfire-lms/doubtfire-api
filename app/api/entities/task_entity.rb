module Entities
  class TaskEntity < Grape::Entity
    format_with(:date_only) do |date|
      date.strftime('%Y-%m-%d')
    end

    expose :id
    expose :project_id, unless: :in_project, expose_nil: false
    expose :task_definition_id

    expose :status

    with_options(format_with: :date_only) do
      expose :due_date
      expose :submission_date, expose_nil: false
      expose :completion_date, expose_nil: false
    end

    expose :extensions

    expose :times_assessed
    expose :grade, expose_nil: false
    expose :quality_pts, expose_nil: false

    expose :include_in_portfolio

    # Attributes excluded from update only

    expose :similarity_flag, unless: :update_only

    expose :num_new_comments, unless: :update_only

    # Attributes only included in "update only"

    expose :new_stats, if: :update_only do |task, options|
      task.project.task_stats
    end

    # Attributes only included if include other projects

    expose :other_projects, expose_nil: false, if: :include_other_projects do |task, options|
      if task.group_task? && !task.group.nil?
        grp = task.group
        grp.projects.select { |p| p.id != task.project_id }.map { |p| { id: p.id, new_stats: p.task_stats } }
      end
    end
  end
end
