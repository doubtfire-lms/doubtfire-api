class ShallowTaskSerializer < ActiveModel::Serializer
  attributes :id, :status, :task_definition_id, :include_in_portfolio, :pct_similar, :similar_to_count, :times_assessed, :grade, :quality_pts, :similar_to_dismissed_count
end

class TaskFeedbackSerializer < ActiveModel::Serializer
  attributes :project_id,
             :id,
             :task_definition_id,
             :tutorial_id,
             :status,
             :completion_date,
             :submission_date,
             :times_assessed,
             :grade,
             :quality_pts,
             :num_new_comments

  def status
    TaskStatus.status_key_for_name(object.status_name)
  end

  def num_new_comments
    # TODO: JAKE - Stub using user first -- need to get actual current user
    # object.new_comments_for_user(User.first)
    Random.rand(0..3)
  end
end

class TaskUpdateSerializer < ActiveModel::Serializer
  attributes :id, :status, :project_id, :new_stats, :include_in_portfolio, :other_projects, :times_assessed, :grade, :quality_pts

  def new_stats
    object.project.task_stats
  end

  def other_projects
    grp = object.group
    others = grp.projects.select { |p| p.id != object.project_id }.map { |p| { id: p.id, new_stats: p.task_stats } }
  end

  def filter(keys)
    keys.delete :other_projects unless object.group_task? && !object.group.nil?
    keys
  end
end

class TaskStatSerializer < ActiveModel::Serializer
  attributes :id, :task_abbr, :status, :tutorial_id, :times_assessed

  def task_abbr
    object.task_definition.abbreviation
  end

  # def tutorial_id
  #   object.project.tutorial.id unless object.project.tutorial.nil?
  # end
end

class TaskSerializer < ActiveModel::Serializer
  attributes :id, :status, :completion_date, :task_name, :task_desc, :task_weight, :task_abbr, :upload_requirements, :pct_similar, :similar_to_count, :times_assessed, :similar_to_dismissed_count

  def task_name
    object.task_definition.name
  end

  def task_desc
    object.task_definition.description
  end

  def task_weight
    object.task_definition.weighting
  end

  def task_abbr
    object.task_definition.abbreviation
  end

  def upload_requirements
    object.task_definition.upload_requirements
  end
end
