class Group < ActiveRecord::Base
  belongs_to :group_set
  belongs_to :tutorial

  has_many :group_memberships
  has_many :projects, -> { where("group_memberships.active = :value", value: true) }, through: :group_memberships
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


end
