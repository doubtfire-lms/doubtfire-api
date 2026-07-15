class UnitContentLink < ApplicationRecord
  CONTEXT_TYPES = %w[grade grade_overview task_definition task_definition_resource].freeze

  belongs_to :unit
  belongs_to :unit_content_site

  validates :context_type, inclusion: { in: CONTEXT_TYPES }
  validates :context_key, :route, presence: true
  validates :context_key, uniqueness: { scope: [:unit_id, :context_type] }
  validate :resource_path_must_exist

  before_validation :normalise_route

  private

  def normalise_route
    self.route = "/#{route.to_s.gsub(%r{\A/+|/+\z}, '')}"
    self.route = '/' if route.blank?
  end

  def resource_path_must_exist
    return unless context_type == 'task_definition_resource'
    return if unit_content_site&.file?(route)

    errors.add(:route, 'must be a file in the selected content site')
  end
end
