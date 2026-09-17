# frozen_string_literal: true

class LmsIntegration < ApplicationRecord
  SOURCES = %w[lti].freeze

  belongs_to :unit
  has_many :lms_group_mappings, dependent: :destroy

  validates :source, inclusion: { in: SOURCES }
  validates :assignment_id, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :unit_id, uniqueness: true

  def self.data_source_for(unit)
    source = unit.lms_integration&.source.presence || 'lti'
    case source
    when 'lti'
      LtiCourseDataSource.new(unit)
    end
  end

  def data_source
    LmsIntegration.data_source_for(unit)
  end

  def mark_unvalidated!
    update!(validated: false, validated_at: nil) if validated? || validated_at.present?
  end
end
