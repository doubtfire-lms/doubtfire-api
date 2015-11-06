class LearningOutcome < ActiveRecord::Base
  include ApplicationHelper

  belongs_to :unit

end