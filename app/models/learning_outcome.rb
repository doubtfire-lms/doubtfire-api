# == Schema Information
#
# Table name: learning_outcomes
#
#  id                       :bigint           not null, primary key
#  short_description        :string(255)
#  full_outcome_description :string(4096)
#  abbreviation             :string(255)
#  context_id               :bigint
#  context_type             :string(255)
#
class LearningOutcome < ApplicationRecord
  include ApplicationHelper
  include FileHelper
  include MimeCheckHelpers
  include CsvHelper

  def self.permissions
    convenor_role_permissions = [
      :update,
      :get_los,
      :update_glos,
      :upload_csv,
      :create_feedback_chips
    ]

    admin_role_permissions = [
      :update,
      :get_los,
      :update_glos,
      :upload_csv,
      :create_feedback_chips
    ]

    tutor_role_permissions = [
      :update,
      :get_los,
      :update_glos
    ]

    auditor_role_permissions = [
      :get_los
    ]

    nil_role_permissions = []

    {
      convenor: convenor_role_permissions,
      admin: admin_role_permissions,
      tutor: tutor_role_permissions,
      auditor: auditor_role_permissions,
      nil: nil_role_permissions
    }
  end

  def role_for(user)
    if context.nil?
      # Global outcomes - only admins can edit.
      # - No convenor level as that gived edit
      if user.has_admin_capability?
        Role.admin
      elsif user.has_tutor_capability?
        Role.tutor
      else # explicit
        nil
      end
    else
      context.role_for(user)
    end
  end

  scope :global_outcomes, -> { where(context_id: nil, context_type: nil) }

  # Where the outcome is defined - TaskDefinition, Unit, nil
  belongs_to :context, polymorphic: true, optional: true

  # Which higher level outcomes does this outcome support
  has_many :outgoing_links, class_name: 'LearningOutcomeLink', foreign_key: 'source_id', dependent: :destroy, inverse_of: :source
  has_many :linked_outcomes, through: :outgoing_links, source: :target

  # Which lower level outcomes are used to demonstrate this outcome?
  has_many :demonstrated_through_outcome_links, class_name: 'LearningOutcomeLink', foreign_key: 'target_id', dependent: :destroy, inverse_of: :target
  has_many :demonstrated_through_outcomes, through: :demonstrated_through_outcome_links, source: :source

  has_many :feedback_group_chips, class_name: 'Feedback::FeedbackGroupChip', dependent: :destroy
  has_many :feedback_template_chips, class_name: 'Feedback::FeedbackTemplateChip', dependent: :destroy
  has_many :feedback_chips, class_name: 'Feedback::FeedbackChip', dependent: :destroy

  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :related_task_definitions, -> { where('learning_outcome_task_links.task_id is NULL') }, through: :learning_outcome_task_links, source: :task_definition # only link staff relations

  validates :short_description, length: { maximum: 100, allow_blank: true }
  validates :full_outcome_description, length: { maximum: 4095, allow_blank: true }
  validates :abbreviation, uniqueness: { scope: %i[context_id context_type] }, length: { maximum: 5, allow_blank: false }

  def self.csv_header
    %w(unit_code task_abbreviation learning_outcome_abbreviation short_description full_outcome_description linked_outcomes)
  end

  def add_csv_row(row)
    unit_code = if context_type == 'Unit'
                  Unit.find(context_id).code
                elsif context_type == 'TaskDefinition'
                  TaskDefinition.find(context_id).unit.code
                elsif context_type.nil?
                  ''
                end
    task_abbreviation = context_type == 'TaskDefinition' ? TaskDefinition.find(context_id).abbreviation : ''
    linked_learning_outcomes = linked_outcomes.pluck(:abbreviation).join(',')

    row << [unit_code, task_abbreviation, abbreviation, short_description, full_outcome_description, linked_learning_outcomes]
  end

  def self.create_from_csv(row, result)
    unit_code = row['unit_code']
    task_abbreviation = row['task_abbreviation']

    if unit_code.present?
      unit = Unit.find_by(code: unit_code)
      unless unit
        result[:errors] << { row: row, message: "Unit #{unit_code} not found" }
        return
      end
    end

    if task_abbreviation.present?
      task_definition = TaskDefinition.find_by(abbreviation: task_abbreviation)
      unless task_definition
        result[:errors] << { row: row, message: "Task #{task_abbreviation} not found" }
        return
      end
      unless unit.task_definitions.include?(task_definition)
        result[:errors] << { row: row, message: "Task #{task_abbreviation} is not linked to unit #{unit_code}" }
        return
      end
      context_type = 'TaskDefinition'
      context_id = task_definition.id
    elsif unit_code.present?
      context_type = 'Unit'
      context_id = unit.id
    else
      context_type = nil
      context_id = nil
    end

    abbreviation = row['learning_outcome_abbreviation']
    if abbreviation.nil?
      result[:errors] << { row: row, message: 'Missing learning_outcome_abbreviation' }
      return
    end
    if abbreviation.length > 5
      result[:errors] << { row: row, message: 'learning_outcome_abbreviation must be less than 5 characters' }
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

    linked_outcomes = row['linked_outcomes'].to_s.split(',').map(&:strip)
    linked_outcome_ids = LearningOutcome.where(abbreviation: linked_outcomes).pluck(:id)
    missing_links = linked_outcomes - LearningOutcome.where(abbreviation: linked_outcomes).pluck(:abbreviation)

    if missing_links.any?
      result[:errors] << { row: row, message: "Linked outcomes #{missing_links.join(', ')} not found" }
      return
    end

    outcome = LearningOutcome.find_or_create_by(context_id: context_id, context_type: context_type, abbreviation: abbreviation)
    outcome.short_description = short_description
    outcome.full_outcome_description = full_outcome_description

    linked_outcome_ids.each do |linked_outcome_id|
      LearningOutcomeLink.find_or_create_by(source_id: outcome.id, target_id: linked_outcome_id)
    end

    outcome.save

    result[:success] << if outcome.new_record?
                          { row: row, message: "Outcome #{abbreviation} created" }
                        else
                          { row: row, message: "Outcome #{abbreviation} updated" }
                        end
  end

  def export_feedback_chips_to_csv
    CSV.generate do |csv|
      csv << Feedback::FeedbackChip.csv_header
      feedback_chips.each do |chip|
        chip.add_csv_row csv
      end
    end
  end

  def update_linked_outcomes(data)
    existing_link_ids = outgoing_links.pluck(:target_id)

    if existing_link_ids.present?
      links_to_delete = if data.present?
                          existing_link_ids - data
                        else
                          existing_link_ids
                        end
    end

    if links_to_delete.present?
      outgoing_links.where(target_id: links_to_delete).destroy_all
    end

    data&.each do |linked_outcome_id|
      LearningOutcomeLink.find_or_create_by!(source_id: id, target_id: linked_outcome_id)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "Failed to link learning outcome #{id} to learning outcome #{linked_outcome_id}: #{e.message}"
    end
  end

  def link_to(linked_outcome)
    return if linked_outcome.nil?
    LearningOutcomeLink.find_or_create_by(
      source_id: id,
      target_id: linked_outcome.id
    )
  end
end
