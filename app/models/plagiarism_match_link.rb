class PlagiarismMatchLink < ActiveRecord::Base
  belongs_to :task
  belongs_to :other_task, :class_name => 'Task'

  #
  # Ensure file is also deleted
  #
  before_destroy do | match_link |
    begin
      if match_link.task.group_task?
        other_tasks = match_link.task.group_submission.tasks.select{|t| t.id != match_link.task.id }

        other_tasks_using_file = other_tasks.select{|t| t.plagiarism_match_links.where(other_task_id: match_link.other_task_id).count > 0 }
        FileHelper.delete_plagarism_html(match_link) unless other_tasks_using_file.count > 0
      else # individual... so can delete file
        FileHelper.delete_plagarism_html(match_link)
      end
    rescue => e
      puts "error deleting match link for task #{match_link.task.id} = #{e.message}"
    end
  end

  after_destroy do | match_link |
    if match_link.other_party
      match_link.other_party.destroy
    end
    match_link.task.recalculate_max_similar_pct
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