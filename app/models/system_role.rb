class SystemRole < ActiveRecord::Base
  	attr_accessible :name

    # Model associations
  	belongs_to :user	# Foreign key

end
