class PlagiarismMatchLink < ActiveRecord::Base
  include LogHelper

  belongs_to :task
  belongs_to :other_task, class_name: 'Task'

  #
  # Ensure file is also deleted
  #
  before_destroy do |match_link|
    begin
      if match_link.task.group_task?
        other_tasks = match_link.task.group_submission.tasks.select { |t| t.id != match_link.task.id }

        other_tasks_using_file = other_tasks.select { |t| t.plagiarism_match_links.where(other_task_id: match_link.other_task_id).count > 0 }
        FileHelper.delete_plagarism_html(match_link) unless other_tasks_using_file.count > 0
      else # individual... so can delete file
        FileHelper.delete_plagarism_html(match_link)
      end
    rescue => e
      logger.error "Error deleting match link for task #{match_link.task.id}. Error: #{e.message}"
    end
  end

  after_destroy do |match_link|
    match_link.other_party.destroy if match_link.other_party
  end

  def other_party
    PlagiarismMatchLink.where(task_id: other_task.id, other_task_id: task.id).first
  end

  def other_student
    other_task.student
  end

  def other_tutor
    other_task.project.tutor_for(other_task.task_definition)
  end

  delegate :student, to: :task

  def tutor
    task.project.tutor_for(task.task_definition)
  end

  def tutorial
    tute = task.project.tutorial_for(task.task_definition)
    tute.nil? ? 'None' : tute.abbreviation
  end

  def other_tutorial
    tute = other_task.project.tutorial_for(other_task.task_definition)
    tute.nil? ? 'None' : tute.abbreviation
  end
end
