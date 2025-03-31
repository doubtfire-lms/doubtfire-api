class UnitDefinition < ApplicationRecord
  has_many :units
  validates :name, presence: true, length: {maximum: 250}
  validates :description, presence: true, length: {maximum: 1000}
  validates :code, presence: true, length: {maximum: 10}
  validates :version, presence: true, length: {maximum: 10}
end
