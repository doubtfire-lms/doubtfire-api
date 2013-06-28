class SubTaskDefinition < ActiveRecord::Base
  attr_accessible :description, :name, :required

  # Model associations
  has_many :sub_tasks, dependent: :destroy
  has_many :badges, dependent: :destroy
end
