class SubTaskDefinition < ActiveRecord::Base
  has_many :badges

  attr_accessible :description, :name
end