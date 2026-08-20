class GroupEnrolmentCondition < CommunicationCondition
  validates :operator, inclusion: { in: ENROLMENT_OPERATORS }

  # The editor narrows the group list by group set first. Deriving the set from
  # the group keeps the two in step, so reopening the condition shows the set
  # the group actually sits in.
  before_validation :align_group_set_with_group

  private

  def align_group_set_with_group
    self.group_set_id = group&.group_set_id
  end
end
