class Enrolment < ActiveRecord::Base
  belongs_to :tutorial
  belongs_to :project

  validates :tutorial, presence: true
  validates :project,  presence: true
end
