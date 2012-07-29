class Project < ActiveRecord::Base
  attr_accessible :project_role

  # Model associations
  belongs_to :team              # Foreign key
  belongs_to :project_status    # Foreign key
  belongs_to :project_template  # Foreign key
  belongs_to :team_membership   # Foreign key

  has_many :tasks

  def overdue_tasks(date=Date.today)
    tasks.select{|task| task.overdue? date }
  end

  def has_commenced?
    Time.zone.now > project_template.start_date
    true
  end

  def has_concluded?
    Time.zone.now > project_template.end_date
  end
end