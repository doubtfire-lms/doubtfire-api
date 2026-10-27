class EmailStaffAction < CommunicationAction
  validates :subject, presence: true
  validates :body, presence: true
  validates :email_tutors, inclusion: { in: [true, false] }
  validates :email_convenors, inclusion: { in: [true, false] }
  validate :staff_recipient?

  private

  def staff_recipient?
    return if email_tutors || email_convenors

    errors.add(:base, 'must email tutors or convenors')
  end
end
