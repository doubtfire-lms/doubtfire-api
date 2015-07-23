#
# Tracks each group's submissions.
#
class GroupSubmission < ActiveRecord::Base
  belongs_to :group
  has_many :tasks, dependent: :nullify
  has_many :projects, through: :tasks
  belongs_to :submitted_by_project, class_name: "Project", foreign_key: 'submitted_by_project_id'


  def propagate_transition initial_task, trigger, by_user
    tasks.each do |task|
      if task != initial_task
        task.trigger_transition(trigger, by_user, bulk=false, group_transition=true)
      end
    end
  end

  def submitter_task
    result = tasks.where(project: submitted_by_project).first
    return result unless result.nil?
    
    tasks.first
  end
end
