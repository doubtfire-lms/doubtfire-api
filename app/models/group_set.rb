class GroupSet < ActiveRecord::Base
	belongs_to :unit
	has_many :groups, dependent: :destroy
end
