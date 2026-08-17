#
# Tracks each group's submissions.
#
class GroupSubmission < ApplicationRecord
  belongs_to :group, optional: false
  belongs_to :task_definition, optional: false
  belongs_to :submitted_by_project, class_name: 'Project', optional: false

  has_many :tasks, dependent: :nullify
  has_many :projects, through: :tasks

  #
  # Ensure file is also deleted
  #
  before_destroy do |group_submission|
    logger.debug "Deleting group submission #{group_submission.id}"
    begin
      FileHelper.delete_group_submission(group_submission)

      # Also remove evidence from group members through the explicit group
      # operation bypass so frozen members cannot be changed by other paths.
      tasks.where.not(portfolio_evidence: nil).find_each do |task|
        with_portfolio_lock_bypass(task) do
          task.update!(portfolio_evidence: nil)
        end
      end
    rescue => e
      logger.error "Failed to delete group submission #{group_submission.id}. Error: #{e.message}"
    end
  end

  def propagate_transition(initial_task, trigger, by_user, quality)
    Task.transaction do
      tasks.each do |task|
        next if [TaskStatus.complete.id, TaskStatus.feedback_exceeded.id, TaskStatus.fail.id].include? task.task_status_id
        next if task == initial_task

        with_portfolio_lock_bypass(task) do
          task.extensions = initial_task.extensions unless initial_task.extensions < task.extensions
          task.trigger_transition(trigger: trigger, by_user: by_user, group_transition: true, quality: quality)
        end
      end
    end
  end

  def propagate_grade(initial_task, new_grade, ui)
    Task.transaction do
      tasks.each do |task|
        next if task == initial_task

        with_portfolio_lock_bypass(task) do
          task.grade_task new_grade, ui, grading_group = true
          task.save!
        end
      end
    end
  end

  def propogate_alignments_from_submission(alignments)
    tasks.each do |task|
      task.create_alignments_from_submission(alignments)
    end
  end

  def submitter_task
    result = tasks.where(project: submitted_by_project).first
    return result unless result.nil?

    tasks.first
  end

  def submitted_by? project
    project == submitted_by_project
  end

  delegate :processing_pdf?, to: :submitter_task

  private

  def with_portfolio_lock_bypass(task)
    task.portfolio_lock_bypass = true
    yield
  ensure
    task.portfolio_lock_bypass = false
  end
end
