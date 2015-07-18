class Group < ActiveRecord::Base
  belongs_to :group_set
  belongs_to :tutorial

  has_many :group_memberships
  has_many :projects, -> { where("group_memberships.active = :value", value: true) }, through: :group_memberships
  has_many :past_projects, -> { where("group_memberships.active = :value", value: false) },  through: :group_memberships, source: 'project'
  has_one :unit, through: :group_set

  validates :group_set, presence: true, allow_nil: false
  validates :tutorial, presence: true, allow_nil: false

  def has_user(user)
    projects.joins(:unit_role).where("unit_roles.user_id = :user_id", user_id: user.id).count == 1
  end

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
    gs = submitter_task.group_submission
    if gs.nil?
      gs = GroupSubmission.create { |gs| 
        gs.group = self
        gs.notes = notes
        gs.submitted_by_project = submitter_task.project
      }
    end
    
    total = 0
    #check all members are in the same group
    contributors.each do |contrib|
      project = contrib[:project]
      total += contrib[:pct].to_i
      raise "Not all contributions were from team members." unless projects.include? project 
    end

    # check for all group members
    raise 'Contributions missing for some group members' unless projects.count == contributors.count

    # check pct
    raise 'Contribution percentages are insufficient.' unless total >= 90
    raise 'Contribution percentages are excessive.' unless total <= 110

    # check group task
    raise "Group submission only allowed for group tasks." unless submitter_task.task_definition.group_set
    raise "Group submission for wrong group for unit." unless submitter_task.task_definition.group_set == group_set

    contributors.each do |contrib|
      project = contrib[:project]
      task = project.matching_task submitter_task

      task.group_submission = gs
      task.contribution_pct = contrib[:pct]
      # puts "id is #{task.group_submission_id}"
      task.save
    end
    gs
  end

end
