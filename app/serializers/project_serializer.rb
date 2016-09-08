require 'task_serializer'

# Shallow serialization is used for student...
class ShallowProjectSerializer < ActiveModel::Serializer
  attributes :unit_id, :project_id, :student_name, :tutor_name, :unit_name, :target_grade, :has_portfolio, :unit_code, :start_date

  def project_id
    object.id
  end

  # def student_name
  #   object.student.name
  # end

  # def unit_name
  #   object.unit.name
  # end

  # def unit_code
  #   object.unit.code
  # end

  # def tutor_name
  #   object.main_tutor.first_name unless object.main_tutor.nil?
  # end
end

class ProjectSerializer < ActiveModel::Serializer
  attributes :unit_id, :project_id, :student_id, :started, :stats, :student_name, :tutor_name, :tutorial_id, :burndown_chart_data, :enrolled, :target_grade, :portfolio_files, :compile_portfolio, :portfolio_available, :grade, :grade_rationale

  def project_id
    object.id
  end

  def student_name
    "#{object.student.name}#{object.student.nickname.nil? ? '' : ' (' << object.student.nickname << ')'}"
  end

  def student_id
    object.student.username
  end

  def tutor_name
    object.main_tutor.first_name unless object.main_tutor.nil?
  end

  def stats
    if object.task_stats.nil? || object.task_stats.empty?
      object.calc_task_stats
    else
      object.task_stats
    end
  end

  has_many :tasks, serializer: ShallowTaskSerializer
  has_many :groups, serializer: GroupSerializer
  has_many :task_outcome_alignments, serializer: LearningOutcomeTaskLinkSerializer

  def my_role_obj
    if Thread.current[:user]
      object.role_for(Thread.current[:user])
    end
  end

  def include_grade?
    ([ Role.convenor, :convenor, Role.tutor, :tutor ].include? my_role_obj)
  end

  def include_grade_rationale?
    ([ Role.convenor, :convenor, Role.tutor, :tutor ].include? my_role_obj)
  end
end

class GroupMemberProjectSerializer < ActiveModel::Serializer
  attributes :student_id, :project_id, :student_name, :target_grade

  def project_id
    object.id
  end

  def student_id
    object.student.username
  end

  def student_name
    "#{object.student.name}#{object.student.nickname.nil? ? '' : ' (' << object.student.nickname << ')'}"
  end

  def my_role_obj
    if Thread.current[:user]
      object.role_for(Thread.current[:user])
    end
  end

  def include_student_id?
    ([ Role.convenor, Role.tutor, :tutor, :convenor ].include? my_role_obj )
  end

end
