#
# Tracks each group's submissions.
#
class GroupSubmission < ActiveRecord::Base
  belongs_to :group
  belongs_to :task_definition
  has_many :tasks, dependent: :nullify
  has_many :projects, through: :tasks
  belongs_to :submitted_by_project, class_name: "Project", foreign_key: 'submitted_by_project_id'

  #
  # Ensure file is also deleted
  #
  before_destroy do | group_submission |
    # puts "Delete group submission!"
    begin
      FileHelper.delete_group_submission(group_submission)

      # also remove evidence from group members
      tasks.each do |t| 
        t.portfolio_evidence = null 
        t.save
      end
    rescue
      puts "Failed to delete group submission #{group_submission.id}!"
    end
  end

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
