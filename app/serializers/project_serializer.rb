require 'task_serializer'

class ShallowProjectSerializer < ActiveModel::Serializer
  attributes :unit_id, :project_id, :started, :progress, :status, :student_name, :tutor_name, :unit_name

  def project_id
    object.id
  end

  def student_name
    object.student.name
  end

  def unit_name
    object.unit.name
  end

  def tutor_name
    object.main_tutor.first_name unless object.main_tutor.nil?
  end

end

class StudentProjectSerializer < ActiveModel::Serializer
  attributes :project_id, :name, :student_id, :student_email, :tute, :stats

  def student_email
    object.student.email
  end

  def project_id
    object.id
  end
  
  def name
    object.student.name
  end

  def student_id
    object.student.username
  end

  def tute
    object.unit_role.tutorial_id
  end  

  def stats
    if object.task_stats.nil? or object.task_stats.empty?
      object.update_task_stats
    else
      object.task_stats
    end
  end
end

class ProjectSerializer < ActiveModel::Serializer
  attributes :unit_id, :project_id, :started, :stats, :student_name, :tutor_name, :tutor_id, :burndown_chart_data

  def project_id
    object.id
  end

  def student_name
  	object.student.name
  end

  def tutor_id
    object.main_tutor.id unless object.main_tutor.nil?
  end

  def tutor_name
  	object.main_tutor.first_name unless object.main_tutor.nil?
  end

  def tute
    object.unit_role.tutorial_id
  end

  def stats
    if object.task_stats.nil? or object.task_stats.empty?
      object.update_task_stats
    else
      object.task_stats
    end
  end

  # has_one :unit, :unit_role
  has_many :tasks, serializer: ShallowTaskSerializer
end
