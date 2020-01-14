class LearningOutcomeTaskLink < ActiveRecord::Base
  belongs_to :task_definition
  belongs_to :task
  belongs_to :learning_outcome

  validates :task_definition, presence: true
  validates :learning_outcome, presence: true
  validate :ensure_relations_unique

  validates :rating, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }

  def ensure_relations_unique
    return if learning_outcome.nil? || task_definition.nil?

    if id.nil?
      related_links = LearningOutcomeTaskLink.where('task_definition_id = :task_definition_id AND learning_outcome_id = :learning_outcome_id', task_definition_id: task_definition.id, learning_outcome_id: learning_outcome.id)
    else
      related_links = LearningOutcomeTaskLink.where('id != :my_id AND task_definition_id = :task_definition_id AND learning_outcome_id = :learning_outcome_id', my_id: id, task_definition_id: task_definition.id, learning_outcome_id: learning_outcome.id)
    end

    if task.nil?
      errors.add(:task_definition, 'already linked to this learning outcome') if related_links.where('task_id is NULL').count > 0
    else
      errors.add(:task, 'already linked to this learning outcome') if related_links.where('task_id = :task_id', task_id: task.id).count > 0
    end
  end

  def duplicate_to(new_unit)
    result = self.dup

    throw "Unable to duplicate project learning outcome task links in unit #{new_unit.code}" if task.present?

    ilo = new_unit.learning_outcomes.find_by(abbreviation: self.learning_outcome.abbreviation)
    throw "Unable to find Learning Outcome #{self.learning_outcome.abbreviation} in unit #{new_unit.code}" if ilo.nil?

    task_def = new_unit.task_definitions.find_by(abbreviation: self.task_definition.abbreviation)
    throw "Unable to find Task Definition #{self.task_definition.abbreviation} in unit #{new_unit.code}" if task_def.nil?

    result.learning_outcome = ilo
    result.task_definition = task_def
    result.task = nil
    result.save
  end

  def self.export_task_alignment_to_csv(unit, source)
    CSV.generate do |row|
      row << %w(unit_code learning_outcome task_abbr rating description)
      source.task_outcome_alignments.each do |align|
        row << [unit.code, align.learning_outcome.abbreviation, align.task_definition.abbreviation, align.rating, align.description]
      end
    end
  end
end
