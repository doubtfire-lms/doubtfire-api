class Group < ActiveRecord::Base
  belongs_to :group_set
  belongs_to :tutorial

  has_many :group_memberships
  has_many :projects, -> { where("group_memberships.active = :value", value: true) }, through: :group_memberships
  has_many :past_projects, -> { where("group_memberships.active = :value", value: false) },  through: :group_memberships, source: 'project'
  has_one :unit, through: :group_sets

  validates :group_set, presence: true, allow_nil: false
  validates :tutorial, presence: true, allow_nil: false


  def add_member(project)
    gm = group_memberships.where(project: project).first

    if gm.nil?
      gm = GroupMembership.create
      gm.group = self
      gm.project = project
    end

    gm.active = true
    gm.save

    gm  
  end

  def remove_member(project)
    gm = group_memberships.where(project: project).first
    gm.active = false
    gm.save
    self
  end

  #
  # The submitter task is the user who submitted this group task.
  #
  # Creates a Group Submission
  # Locates other group members, and link to this submission.
  #   - contributors contains [ {project: ..., pct: ... } ]
  #
  def create_submission(submitter_task, notes, contributors)
    gs = GroupSubmission.create { |gs| 
        gs.group = self
        gs.notes = notes
        gs.submitted_by_project = submitter_task.project
      }
    
    contributors.each do |contrib|
      project = contrib[:project]
      task = project.matching_task submitter_task

      task.group_submission = gs
      task.contribution_pct = contrib[:pct]
      puts "id is #{task.group_submission_id}"
      task.save
    end
    gs
  end

end
