# frozen_string_literal: true

class MossTaskSimilarity < TaskSimilarity
  belongs_to :other_task, class_name: 'Task'

  def file_path
    FileHelper.path_to_plagarism_html(self)
  end

  #
  # Ensure file is also deleted
  #
  before_destroy do |similarity|
    if similarity.task.group_task?
      other_tasks = similarity.task.group_submission.tasks.reject { |t| t.id == similarity.task.id }

      other_tasks_using_file = other_tasks.select { |t| t.task_similarities.where(other_task_id: similarity.other_task_id).count > 0 }
      FileHelper.delete_plagarism_html(similarity) unless other_tasks_using_file.count > 0
    else # individual... so can delete file
      FileHelper.delete_plagarism_html(similarity)
    end
  rescue StandardError => e
    logger.error "Error deleting match link for task #{similarity.task.id}. Error: #{e.message}"
  end

  after_destroy do |similarity|
    similarity.other_similarity&.destroy
  end

  def other_similarity
    MossTaskSimilarity.where(task_id: other_task.id, other_task_id: task.id).first unless other_task.nil?
  end

  def other_student
    other_task&.student
  end

  def other_tutor
    other_task&.project&.tutor_for(other_task.task_definition)
  end

  def other_tutorial
    tute = other_task.project.tutorial_for(other_task.task_definition) unless other_task.nil?
    tute.nil? ? 'None' : tute.abbreviation
  end

  def ready_for_viewer?
    true
  end
end
