class LearningOutcome < ApplicationRecord
  include ApplicationHelper

  belongs_to :context, polymorphic: true

  has_many :outgoing_links, class_name: 'LearningOutcomeLink', foreign_key: 'source_id', dependent: :destroy
  has_many :linked_outcomes, through: :outgoing_links, source: :target

  has_many :incoming_links, class_name: 'LearningOutcomeLink', foreign_key: 'target_id', dependent: :destroy
  has_many :linked_by_outcomes, through: :incoming_links, source: :source

  has_many :feedback_group_chips, class_name: 'Feedback::FeedbackGroupChip', dependent: :destroy
  has_many :feedback_template_chips, class_name: 'Feedback::FeedbackTemplateChip', dependent: :destroy

  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :related_task_definitions, -> { where('learning_outcome_task_links.task_id is NULL') }, through: :learning_outcome_task_links, source: :task_definition # only link staff relations

  # validates :abbreviation, uniqueness: { scope: :unit_id } # abbreviation was changed to tag, and now we want to use context type
  # validates :tag, uniqueness: { scope: :context_type } # outcome names within a unit must be unique
  validates :short_description, length: { maximum: 4095, allow_blank: true }
  validates :full_outcome_description, length: { maximum: 4095, allow_blank: true }

  def self.csv_header
    %w(context_type, context_id, abbreviation, short_description, full_outcome_description)
  end

  def add_csv_row(row)
    row << [context_type, context_id, abbreviation, short_description, full_outcome_description]
  end

  def self.create_from_csv(context, row, result)
    context_type = row['context_type']
    context_id = row['context_id'].to_i
    # unit_code = row['unit_code']

    if context_type != context.class.name || context_id != context.id
      result[:ignored] << { row: row, message: "Invalid context. #{context_type} #{context_id} does not match #{context.class.name} #{context.id}" }
      return
    end
    # if unit_code != unit.code
    #  result[:ignored] << { row: row, message: "Invalid unit code. #{unit_code} does not match #{unit.code}" }
    #  return
    # end

    # ilo_number = row['ilo_number'].to_i

=begin
  tag = row['tag']
    if tag.nil?
      result[:errors] << { row: row, message: 'Missing tag' }
      return
    end

    name = row['name']
    if name.nil?
      result[:errors] << { row: row, message: 'Missing name' }
      return
    end

    description = row['description']
    if description.nil?
      result[:errors] << { row: row, message: 'Missing description' }
      return
    end
=end

    abbreviation = row['abbreviation']
    if abbreviation.nil?
      result[:errors] << { row: row, message: 'Missing abbreviation' }
      return
    end

    short_description = row['short_description']
    if short_description.nil?
      result[:errors] << { row: row, message: 'Missing short_description' }
      return
    end

    full_outcome_description = row['full_outcome_description']
    if full_outcome_description.nil?
      result[:errors] << { row: row, message: 'Missing full_outcome_description' }
      return
    end

    outcome = LearningOutcome.find_or_create_by(context_id: context_id, context_type: context_type, abbreviation: abbreviation) do |outcome|
      outcome.short_description = short_description
      outcome.full_outcome_description = full_outcome_description
    end

    outcome.save!

    result[:success] << if outcome.new_record?
                          { row: row, message: "Outcome #{abbreviation} created" }
                        else
                          { row: row, message: "Outcome #{abbreviation} updated" }
                        end
  end
end
