# frozen_string_literal: true

class TaskSimilarity < ApplicationRecord

  belongs_to :task, optional: false

  validates :pct, presence: true, inclusion: { in: 0..100, message: "%{value} is not a valid percent" }

  delegate :student, to: :task

  def tutor
    task.project.tutor_for(task.task_definition)
  end

  def tutorial
    tute = task.project.tutorial_for(task.task_definition)
    tute.nil? ? 'None' : tute.abbreviation
  end

  def ready_for_viewer?
    false
  end

end
