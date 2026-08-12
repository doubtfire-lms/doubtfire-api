# == Schema Information
#
# Table name: feedback_chips
#
#  id                  :bigint           not null, primary key
#  type                :string(255)
#  chip_text           :text(65535)
#  description         :text(65535)
#  comment_text        :text(65535)
#  summary_text        :text(65535)
#  learning_outcome_id :bigint           not null
#  parent_chip_id      :bigint
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  task_status         :string(255)
#
module Feedback
  class FeedbackChip < ApplicationRecord
    self.inheritance_column = :type

    validates :chip_text, presence: true, length: { maximum: 20 }
    validates :description, presence: true, length: { maximum: 116 }

    belongs_to :parent_chip, class_name: 'FeedbackChip', optional: true
    belongs_to :learning_outcome, class_name: 'LearningOutcome', optional: true

    has_many :child_chips, class_name: 'FeedbackChip', foreign_key: 'parent_chip_id', dependent: :nullify, inverse_of: :parent_chip
    has_many :chip_usages, class_name: 'ChipUsage', dependent: :destroy

    validate :parent_chip_cannot_create_loop, if: :parent_chip_id_changed?
    validate :parent_is_group_chip_in_same_context, if: :parent_chip_id_changed?

    def self.permissions
      convenor_role_permissions = [
        :update_chip,
        :delete_feedback_chips
      ]

      admin_role_permissions = [
        :update_chip,
        :delete_feedback_chips
      ]

      nil_role_permissions = []

      {
        convenor: convenor_role_permissions,
        admin: admin_role_permissions,
        tutor: nil_role_permissions,
        student: nil_role_permissions,
        auditor: nil_role_permissions,
        nil: nil_role_permissions
      }
    end

    delegate :role_for, to: :learning_outcome

    def track_usage_by(tutor)
      analytics = chip_usage_analytics.find_or_initialize_by(tutor: tutor)
      analytics.usage_count += 1
      analytics.save
    end

    def self.global_chips
      Feedback::FeedbackChip.joins(:learning_outcome).where(learning_outcome: { context_type: nil, context_id: nil })
    end

    def children
      FeedbackChip.where(parent_chip_id: self.id, learning_outcome_id: self.learning_outcome_id)
    end

    def feedback_type
      if is_a?(Feedback::FeedbackGroupChip)
        'group'
      elsif is_a?(Feedback::FeedbackTemplateChip)
        'template'
      else
        'something went wrong'
      end
    end

    def parent_is_group_chip_in_same_context
      if parent_chip
        if parent_chip.type != 'Feedback::FeedbackGroupChip'
          errors.add(:parent_chip, 'must be a group chip')
        end
        if parent_chip.learning_outcome_id != learning_outcome_id
          errors.add(:parent_chip, 'must be in the same learning outcome')
        end
      end
    end

    def parent_chip_cannot_create_loop
      if parent_chip_id.present? && descendant_of?(parent_chip_id)
        errors.add(:parent_chip_id, 'cannot create a loop')
      end
    end

    def descendant_of?(parent_chip_id)
      current_chip_id = parent_chip_id
      while current_chip_id
        return true if current_chip_id == self.id
        current_chip_id = FeedbackChip.where(id: current_chip_id).pick(:parent_chip_id)
      end
    end

    TYPE_MAPPING = {
      'template' => 'Feedback::FeedbackTemplateChip',
      'group' => 'Feedback::FeedbackGroupChip'
    }.freeze

    def self.to_csv_type(db_type)
      TYPE_MAPPING.key(db_type) || db_type
    end

    def self.from_csv_type(csv_type)
      TYPE_MAPPING[csv_type] || csv_type
    end

    def self.csv_header
      %w[unit_code task_abbreviation learning_outcome_abbreviation type group_id parent_group_id chip_text description task_status summary_text comment_text]
    end

    def add_csv_row(row)
      csv_type = self.class.to_csv_type(type)

      learning_outcome = LearningOutcome.find(learning_outcome_id)

      context_type = learning_outcome.context_type
      context_id = learning_outcome.context_id

      unit_code = nil
      if context_type == 'Unit'
        unit_code = Unit.find(context_id).code
      elsif context_type == 'TaskDefinition'
        unit_code = TaskDefinition.find(context_id).unit.code
      end

      learning_outcome_abbreviation = learning_outcome.abbreviation
      task_abbreviation = learning_outcome.context_type == 'TaskDefinition' ? TaskDefinition.find(learning_outcome.context_id).abbreviation : nil

      group_id = nil
      parent_group_id = nil
      summary_text = self.summary_text
      if csv_type == 'group'
        group_id = summary_text
        summary_text = nil
      end

      if parent_chip_id.present?
        parent_group_id = FeedbackChip.find(parent_chip_id).summary_text
        if parent_group_id.nil?
          parent_group_id = FeedbackChip.find(parent_chip_id).chip_text
        end
      end

      row << [unit_code, task_abbreviation, learning_outcome_abbreviation, csv_type, group_id, parent_group_id, chip_text, description, task_status, summary_text, comment_text]
    end

    def self.import_feedback_chips_from_csv(file, context_type, context)
      result = {
        success: [],
        errors: [],
        ignored: []
      }

      data = FileHelper.read_file_to_str(file)

      CSV.parse(data,
                headers: true,
                header_converters: [->(i) { i.nil? ? '' : i }, :downcase, ->(hdr) { hdr&.strip }],
                converters: [->(body) { body&.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') }]).each do |row|
        # Make sure we're not looking at the header or an empty line
        next if row[0] =~ /unit_code/

        begin
          Feedback::FeedbackChip.create_from_csv(row, context_type, context, result)
        rescue StandardError => e
          result[:errors] << { row: row, message: e.message.to_s }
        end
      end

      result
    end

    # Get the context for the CSV row
    # Returns:
    # - {
    #     success: true if the context is valid
    #     message: error message if success is false
    #     unit:,
    #     task_definition:
    #     learning_outcome:
    #   }
    def self.context_for_csv(row, context_type, context)
      # Find unit - which contains task definition if present
      unit_code = row['unit_code']
      if unit_code.present?
        unit = if context_type == 'TaskDefinition'
                 context.unit
               elsif context_type == 'LearningOutcome' && context.context_type == 'TaskDefinition'
                 context.context.unit
               elsif context_type == 'LearningOutcome'
                 context.context
               else
                 context
               end
        if unit.nil?
          return { success: false, message: "Unit #{unit_code} not found" }
        elsif unit_code != unit.code
          return { success: false, message: "Unit #{unit_code} does not match unit #{unit.code}" }
        end
      elsif %w[Unit TaskDefinition].include? context_type
        # the unit code is not present, but the context is a unit or task definition
        return { success: false, message: "Is not for unit #{context_type == 'Unit' ? context.code : context.unit.code}" }
      end

      task_abbreviation = row['task_abbreviation']
      if task_abbreviation.present?
        if unit.nil? && task_abbreviation.present?
          return { success: false, message: 'Task abbreviation is missing unit code' }
        end
        task_definition = unit.task_definitions.where(abbreviation: task_abbreviation).select(:id).first
        if task_definition.nil?
          return { success: false, message: "Task #{task_abbreviation} not found" }
        end
        if context_type == 'TaskDefinition' && context.id != task_definition.id
          # Supposed to be in the task definition, but it's in another td
          return { success: false, message: "Is not for task #{context.abbreviation}" }
        end
      elsif context_type == 'TaskDefinition'
        # the task abbreviation is not present, but the context is a task definition
        return { success: false, message: "Is not for task #{context.abbreviation}" }
      end

      learning_outcome_abbreviation = row['learning_outcome_abbreviation']
      if learning_outcome_abbreviation.nil?
        return { success: false, message: 'Missing learning outcome abbreviation' }
      end

      search_context = task_definition || (context_type == 'LearningOutcome' ? context.context : context)
      learning_outcome = LearningOutcome.find_by(abbreviation: learning_outcome_abbreviation, context: search_context)

      if learning_outcome.nil?
        return { success: false, message: "Learning outcome #{learning_outcome_abbreviation} not found" }
      end
      if context_type == 'LearningOutcome' && context.id != learning_outcome.id
        return { success: false, message: "Is not for learning outcome #{context.abbreviation}" }
      end

      {
        success: true,
        unit: unit,
        task_definition: task_definition,
        learning_outcome: learning_outcome
      }
    end

    def self.create_from_csv(row, context_type, context, result)
      context_result = context_for_csv(row, context_type, context)
      unless context_result[:success]
        result[:errors] << { row: row, message: context_result[:message] }
        return
      end

      # Get the context for easy access
      unit = context_result[:unit]
      task_definition = context_result[:task_definition]
      learning_outcome = context_result[:learning_outcome]

      required_fields = {
        'type' => row['type'],
        'chip_text' => row['chip_text'],
        'description' => row['description']
      }

      required_fields.each do |field, value|
        if value.nil?
          result[:errors] << { row: row, message: "Missing #{field}" }
        end
      end

      type = row['type']
      group_id = row['group_id']
      if group_id.nil? && type == 'group'
        result[:errors] << { row: row, message: 'Missing group_id' }
        return
      end

      parent_group_id = row['parent_group_id']
      parent_chip_id = nil
      if parent_group_id.present?
        parent_chip_id = FeedbackChip.where(summary_text: parent_group_id, learning_outcome_id: learning_outcome.id).pick(:id)
        if parent_chip_id.nil?
          result[:errors] << { row: row, message: "Parent group_id #{parent_group_id} not found" }
          return
        end
      end

      chip_text = row['chip_text']
      description = row['description']

      task_status = row['task_status']
      if task_status.present?
        task_status_check = TaskStatus.status_for_name(task_status)
        if task_status_check.nil?
          result[:errors] << { row: row, message: "Task status #{task_status} not found" }
          return
        end
      end

      summary_text = row['type'] == 'group' ? group_id : row['summary_text'] # store group_id in summary_text for group chips
      comment_text = row['comment_text']

      csv_type = if type == 'group'
                   'Feedback::FeedbackGroupChip'
                 elsif type == 'template'
                   'Feedback::FeedbackTemplateChip'
                 end
      if csv_type.nil?
        result[:errors] << { row: row, message: "Invalid type #{type}" }
        return
      end

      # Type and learning outcome cannot change - find or create by chip_text
      chip = FeedbackChip.find_or_create_by(
        learning_outcome_id: learning_outcome.id,
        type: csv_type,
        chip_text: chip_text
      )

      # Update the other details
      chip.description = description
      chip.task_status = task_status
      chip.parent_chip_id = parent_chip_id
      chip.summary_text = summary_text
      chip.comment_text = comment_text

      chip.save!

      if chip.persisted?
        result[:success] << { row: row, message: "#{chip.new_record? ? 'Created' : 'Updated'} chip #{row['chip_text']}" }
      else
        result[:errors] << { row: row, message: "Chip #{chip_text} not created - #{chip.errors.full_messages.join('. ')}" }
      end
    end
  end
end
