module Feedback
  class FeedbackChip < ApplicationRecord
    self.inheritance_column = :type

    validates :chip_text, presence: true
    validates :description, presence: true

    belongs_to :parent_chip, class_name: 'FeedbackChip', optional: true
    belongs_to :learning_outcome, class_name: 'LearningOutcome', optional: true

    has_many :child_chips, class_name: 'FeedbackChip', foreign_key: 'parent_chip_id', dependent: :nullify
    has_many :chip_usage_analytics, class_name: 'ChipUsageAnalytics', dependent: :destroy

    validate :parent_chip_cannot_create_loop, if: :parent_chip_id_changed?
    # validate :parent_is_group_chip

    # validate :check_learning_outcome_consistency # temporary to test rollover
    # validate :check_single_root_chip_per_learning_outcome # there can be multiple root chips
    # validate :check_tree_completeness_per_learning_outcome, on: [:update]
    # validate :check_no_orphaned_chips

    def track_usage_by(tutor)
      analytics = chip_usage_analytics.find_or_initialize_by(tutor: tutor)
      analytics.usage_count += 1
      analytics.save
    end

    def children
      FeedbackChip.where(parent_chip_id: self.id, learning_outcome_id: self.learning_outcome_id)
    end

    def serialize
      {
        id: self.id,
        type: feedback_type,
        chip_text: self.chip_text,
        description: self.description,
        parent_chip_id: self.parent_chip_id,
        learning_outcome_id: self.learning_outcome_id
      }
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

    def parent_is_group_chip
      if parent_chip_id.present?
        parent_chip = FeedbackChip.find_by(id: parent_chip_id)
        if parent_chip && parent_chip.type != 'Feedback::FeedbackGroupChip'
          errors.add(:parent_chip_id, 'must be a group chip')
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
        current_chip_id = FeedbackChip.find_by(id: current_chip_id)&.parent_chip_id
      end
    end

    def check_no_orphaned_chips
      if parent_chip_id.present?
        parent_chip = FeedbackChip.find_by(id: parent_chip_id)
        errors.add(:parent_chip_id, 'must exist and be a valid chip') unless parent_chip
      end
    end

    def check_learning_outcome_consistency
      if parent_chip_id.present?
        parent_chip = FeedbackChip.find_by(id: parent_chip_id)
        if parent_chip.learning_outcome_id != self.learning_outcome_id
          errors.add(:learning_outcome_id, 'must be consistent with parent chip')
        end
      end
    end

=begin
    def check_single_root_chip_per_learning_outcome
      if parent_chip_id.nil? && FeedbackGroupChip.where(learning_outcome_id: self.learning_outcome_id, parent_chip_id: nil).count > 1
        errors.add(:base, 'Only one root chip allowed per learning outcome')
      end
    end
=end

    def check_tree_completeness_per_learning_outcome
      if parent_chip_id.nil?
        reachable_chips = reachable_chips_from_root
        all_chips_for_learning_outcome = FeedbackGroupChip.where(learning_outcome_id: self.learning_outcome_id)
        if reachable_chips.count != all_chips_for_learning_outcome.count
          errors.add(:base, 'Tree is not complete for the learning outcome; some chips are orphaned and unreachable')
        end
      end
    end

    def reachable_chips_from_root
      visited = Set.new
      stack = [self]

      while stack.any?
        chip = stack.pop
        next if visited.include?(chip)
        visited.add(chip)
        stack.push(*chip.children)
      end
      visited.to_a
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

=begin
    def self.csv_header
      %w(type chip_text description task_status parent_chip_id learning_outcome_id summary_text comment_text)
    end

    def add_csv_row(row)
      csv_type = self.class.to_csv_type(type)
      row << [csv_type, chip_text, description, task_status, parent_chip_id, learning_outcome_id, summary_text, comment_text]
    end

    def self.create_from_csv(outcome, row, result)
      outcome_id = row['learning_outcome_id'].to_i

      if outcome_id != outcome.id
        result[:ignored] << { row: row, message: "Invalid outcome. Learning Outcome Id: #{outcome_id} does not match Learning Outcome Id: #{outcome.id}"}
      end

      type = to_db_type(row['type'])
      if type.nil?
        result[:errors] << { row: row, message: 'Missing type' }
      end

      chip_text = row['chip_text']
      if chip_text.nil?
        result[:errors] << { row: row, message: 'Missing abbreviation' }
        return
      end

      description = row['description']
      if description.nil?
        result[:errors] << { row: row, message: 'Missing description' }
        return
      end

      learning_outcome_id = row['learning_outcome_id']
      if learning_outcome_id.nil?
        result[:errors] << { row: row, message: 'Missing learning_outcome_id' }
        return
      end

      parent_chip_id = row['parent_chip_id']
      summary_text = row['summary_text']
      comment_text = row['comment_text']
      task_status = row['task_status']

      chip = FeedbackChip.find_or_create_by(type: type, chip_text: chip_text, description: description, learning_outcome_id: learning_outcome_id) do |chip|
        chip.task_status = task_status
        chip.parent_chip_id = parent_chip_id
        chip.summary_text = summary_text
        chip.comment_text = comment_text
      end

      chip.save!

      result[:success] << if chip.new_record?
                            { row: row, message: "Chip #{chip_text} created" }
                          else
                            { row: row, message: "Chip #{chip_text} updated" }
                          end
    end
=end

    def self.csv_header
      %w(learning_outcome_abbreviation task_abbreviation type group_id parent_group_id chip_text description task_status summary_text comment_text)
    end

    def add_csv_row(row)
      csv_type = self.class.to_csv_type(type)

      learning_outcome = LearningOutcome.find(learning_outcome_id)
      learning_outcome_abbreviation = learning_outcome.abbreviation
      task_abbreviation = learning_outcome.context_type == 'TaskDefinition' ? TaskDefinition.find(learning_outcome.context_id).abbreviation : ''

      group_id = ''
      parent_group_id = ''
      summary_text = self.summary_text
      if csv_type == 'group'
        group_id = summary_text
        summary_text = ''
      end

      if parent_chip_id.present?
        parent_group_id = FeedbackChip.find(parent_chip_id).summary_text
      end

      row << [learning_outcome_abbreviation, task_abbreviation, csv_type, group_id, parent_group_id, chip_text, description, task_status, summary_text, comment_text]
    end

    def self.create_from_csv(outcome, row, result)
      @group_map ||= {}

      learning_outcome_abbreviation = row['learning_outcome_abbreviation']
      learning_outcome = LearningOutcome.find_by(abbreviation: learning_outcome_abbreviation)
      if learning_outcome.nil?
        result[:errors] << { row: row, message: "Learning Outcome #{learning_outcome_abbreviation} not found" }
        return
      end

      task_abbreviation = row['task_abbreviation']
      if task_abbreviation.present? && learning_outcome.context_type == 'TaskDefinition'
        task_definition = TaskDefinition.find_by(abbreviation: task_abbreviation)
        if task_definition.nil?
          result[:errors] << { row: row, message: "Task #{task_abbreviation} not found" }
          return
        end
      end

      required_fields = {
        'type' => row['type'],
        'chip_text' => row['chip_text'],
        'description' => row['description']
      }

      required_fields.each do |field, value|
        if value.nil?
          result[:errors] << { row: row, message: "Missing #{field}" }
          return
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
        parent_chip_id = @group_map[parent_group_id]
        if parent_chip_id.nil?
          result[:errors] << { row: row, message: "Parent group_id #{parent_group_id} not found" }
          return
        end
      end

      chip_text = row['chip_text']
      description = row['description']

      task_status = row['task_status']
      summary_text = row['type'] == 'group' ? group_id : row['summary_text'] # store group_id in summary_text for group chips
      comment_text = row['comment_text']

      if type == 'group'
        csv_type = 'Feedback::FeedbackGroupChip'
      elsif type == 'template'
        csv_type = 'Feedback::FeedbackTemplateChip'
      else
        result[:errors] << { row: row, message: "Invalid type #{type}" }
        return
      end

      chip = FeedbackChip.find_or_create_by(type: csv_type, chip_text: chip_text, description: description, learning_outcome_id: learning_outcome.id) do |chip|
        chip.task_status = task_status
        chip.parent_chip_id = parent_chip_id
        chip.summary_text = summary_text
        chip.comment_text = comment_text
      end

      if chip.persisted?
        result[:success] << { row: row, message: "#{chip.new_record? ? 'Created' : 'Updated'} chip #{row['chip_text']}" }
        @group_map[group_id] = chip.id if row['type'] == 'group'
      else
        result[:errors] << { row: row, message: "Chip #{chip_text} not created" }
      end
    end
  end
end
