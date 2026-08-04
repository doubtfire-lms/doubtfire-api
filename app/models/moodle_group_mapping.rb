# frozen_string_literal: true

class MoodleGroupMapping < ApplicationRecord
  TARGET_TYPES = %w[group campus tutorial].freeze

  belongs_to :moodle_integration
  belongs_to :group_set, optional: true
  belongs_to :group, optional: true
  belongs_to :campus, optional: true
  belongs_to :tutorial_stream, optional: true
  belongs_to :tutorial, optional: true

  validates :moodle_group_id, numericality: { only_integer: true, greater_than: 0 }
  validates :moodle_group_id, uniqueness: { scope: :moodle_integration_id }
  validates :moodle_group_name, presence: true
  validates :target_type, inclusion: { in: TARGET_TYPES }
  validate :valid_target

  private

  def valid_target
    unit = moodle_integration&.unit

    case target_type
    when 'group'
      errors.add(:group_set, 'must be selected') if group_set.blank?
      errors.add(:group_set, 'must belong to this unit') if group_set.present? && group_set.unit != unit
      if create_if_missing?
        if tutorial.blank? == tutorial_stream.blank?
          errors.add(:base, 'select an existing tutorial or a tutorial stream for the new group')
        end
        errors.add(:tutorial, 'must belong to this unit') if tutorial.present? && tutorial.unit != unit
        if tutorial_stream.present? && tutorial_stream.unit != unit
          errors.add(:tutorial_stream, 'must belong to this unit')
        end
      else
        errors.add(:group, 'must be selected') if group.blank?
        if group.present? && (group.group_set != group_set || group.unit != unit)
          errors.add(:group, 'must belong to the selected group set')
        end
      end
    when 'campus'
      errors.add(:campus, 'must be selected') if campus.blank?
    when 'tutorial'
      errors.add(:tutorial_stream, 'must be selected') if tutorial_stream.blank?
      if tutorial_stream.present? && tutorial_stream.unit != unit
        errors.add(:tutorial_stream, 'must belong to this unit')
      end
      unless create_if_missing?
        errors.add(:tutorial, 'must be selected') if tutorial.blank?
        if tutorial.present? && (tutorial.tutorial_stream != tutorial_stream || tutorial.unit != unit)
          errors.add(:tutorial, 'must belong to the selected tutorial stream')
        end
      end
    end
  end
end
