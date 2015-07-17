#
# Records which students are in this group... used to determine the related students on submission
#
class GroupMembership < ActiveRecord::Base
  belongs_to :group
  belongs_to :project


    
end
