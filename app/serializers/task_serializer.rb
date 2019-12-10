# Doubtfire will deprecate ActiveModelSerializer in the future.
# Instead, write a serialize method on the model.

class TaskUpdateSerializer < ActiveModel::Serializer
  attributes :id, :status, :project_id, :new_stats, :include_in_portfolio, :other_projects, :times_assessed, :grade, :quality_pts, :due_date, :extensions

  def new_stats
    object.object.project.task_stats
  end

  def other_projects
    return nil unless object.object.group_task? && !object.object.group.nil?
    grp = object.object.group
    grp.projects.select { |p| p.id != object.object.project_id }.map { |p| { id: p.id, new_stats: p.task_stats } }
  end

end

class TaskStatSerializer < ActiveModel::Serializer
  attributes :id, :task_abbr, :status, :tutorial_id, :times_assessed

  def task_abbr
    object.object.task_definition.abbreviation
  end

  # def tutorial_id
  #   object.object.project.tutorial.id unless object.object.project.tutorial.nil?
  # end
end

class TaskSerializer < ActiveModel::Serializer
  attributes :id, :status, :completion_date, :due_date, :extensions, :task_name, :task_desc, :task_weight, :task_abbr, :upload_requirements, :pct_similar, :similar_to_count, :times_assessed, :similar_to_dismissed_count

  def task_name
    object.object.task_definition.name
  end

  def task_desc
    object.object.task_definition.description
  end

  def task_weight
    object.object.task_definition.weighting
  end

  def task_abbr
    object.object.task_definition.abbreviation
  end

  def upload_requirements
    object.object.task_definition.upload_requirements
  end
end
