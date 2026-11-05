class SkillFramework < ApplicationRecord
  has_many :skills, dependent: :restrict_with_exception
  has_many :course_frameworks, dependent: :destroy
  has_many :courses, through: :course_frameworks

  validates :code, :name, :version, presence: true
  validates :code, uniqueness: { scope: :version }
end
