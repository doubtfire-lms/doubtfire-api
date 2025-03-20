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
      :upload_csv
    ]

    admin_role_permissions = [
      :update,
      :get_los,
      :update_glos,
      :upload_csv
    ]

    tutor_role_permissions = [
      :update,
      :get_los,
      :update_glos
    ]

    nil_role_permissions = []

    {
      convenor: convenor_role_permissions,
      admin: admin_role_permissions,
      tutor: tutor_role_permissions,
      nil: nil_role_permissions
    }
  end

  def role_for(user)
    if user.has_admin_capability?
      Role.admin
    elsif user.has_convenor_capability?
      Role.convenor
    elsif user.has_tutor_capability?
      Role.tutor
    else
      nil
    end
  end

  belongs_to :context, polymorphic: true, optional: true

  has_many :outgoing_links, class_name: 'LearningOutcomeLink', foreign_key: 'source_id', dependent: :destroy
  has_many :linked_outcomes, through: :outgoing_links, source: :target

  has_many :incoming_links, class_name: 'LearningOutcomeLink', foreign_key: 'target_id', dependent: :destroy
  has_many :linked_by_outcomes, through: :incoming_links, source: :source

  has_many :feedback_group_chips, class_name: 'Feedback::FeedbackGroupChip', dependent: :destroy
  has_many :feedback_template_chips, class_name: 'Feedback::FeedbackTemplateChip', dependent: :destroy
  has_many :feedback_chips, class_name: 'Feedback::FeedbackChip', dependent: :destroy

  has_many :learning_outcome_task_links, dependent: :destroy # links to learning outcomes
  has_many :related_task_definitions, -> { where('learning_outcome_task_links.task_id is NULL') }, through: :learning_outcome_task_links, source: :task_definition # only link staff relations

  validates :short_description, length: { maximum: 4095, allow_blank: true }
  validates :full_outcome_description, length: { maximum: 4095, allow_blank: true }
  validates :abbreviation, uniqueness: { scope: %i[context_id context_type] }

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
    CSV.generate do |row|
      row << Feedback::FeedbackChip.csv_header
      feedback_chips.each do |chip|
        chip.add_csv_row row
      end
    end
  end

  def import_feedback_chips_from_csv(file)
    result = {
      success: [],
      errors: [],
      ignored: []
    }

    data = read_file_to_str(file)

    CSV.parse(data,
              headers: true,
              header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr.strip unless hdr.nil? }],
              converters: [->(body) { body.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') unless body.nil? }]).each do |row|
      # Make sure we're not looking at the header or an empty line
      next if row[0] =~ /unit_code/

      begin
        Feedback::FeedbackChip.create_from_csv(row, result)
      rescue Exception => e
        result[:errors] << { row: row, message: e.message.to_s }
      end
    end

    result
  end
end
