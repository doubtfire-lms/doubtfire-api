class Course < ApplicationRecord
  KINDS = %w[degree major minor].freeze

  has_many :course_frameworks, dependent: :destroy
  has_many :skill_frameworks, through: :course_frameworks
  has_many :course_skill_requirements, dependent: :destroy
  has_many :course_unit_definitions, dependent: :destroy
  has_many :unit_definitions, through: :course_unit_definitions
  has_many :course_enrolments, dependent: :restrict_with_exception

  validates :code, :name, :version, :kind, presence: true
  validates :code, uniqueness: { scope: :version }
  validates :kind, inclusion: { in: KINDS }
end
