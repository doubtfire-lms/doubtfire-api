class Skill < ApplicationRecord
  belongs_to :skill_framework
  has_many :skill_levels, dependent: :restrict_with_exception

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :skill_framework_id }
end
