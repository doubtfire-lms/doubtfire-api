class PlagiarismMatchLink < ActiveRecord::Base
  belongs_to :task
  belongs_to :other_task, :class_name => 'Task'

  #
  # Ensure file is also deleted
  #
  before_destroy do | match_link |
    begin
      FileHelper.delete_plagarism_html(match_link)
    rescue
    end
  end

  #
  # Update task's cache of pct similar
  #
  after_save do | match_link |
    task = match_link.task
    if task.max_pct_similar < match_link.pct 
      task.max_pct_similar = match_link.pct 
      task.save
    end
  end

  def other_party
    PlagiarismMatchLink.where(task_id: other_task.id, other_task_id: task.id).first
  end

  def other_student
    other_task.student
  end

  def other_tutor
    other_task.project.main_tutor
  end

  def student
    task.student
  end

  def tutor
    task.project.main_tutor
  end

  def tutorial
    if task.project.tutorial.nil?
      "None"
    else
      task.project.tutorial.abbreviation
    end
  end

  def other_tutorial
    if other_task.project.tutorial.nil?
      "None"
    else
      other_task.project.tutorial.abbreviation
    end
  end

end