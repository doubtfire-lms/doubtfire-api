class UnitDefinition < ApplicationRecord
  has_many :units, dependent: :restrict_with_exception
  has_many :unit_definition_skill_requirements, dependent: :destroy
  has_many :course_unit_definitions, dependent: :destroy
  has_many :courses, through: :course_unit_definitions

  validates :code, :name, :version, presence: true
  validates :version, uniqueness: { scope: :code }
end
