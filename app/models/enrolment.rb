class Enrolment < ActiveRecord::Base
  belongs_to :tutorial
  belongs_to :project

  validates :tutorial, presence: true
  validates :project,  presence: true

  validates_uniqueness_of :tutorial, :scope => :project, message: 'already exists for the selected student'
end
