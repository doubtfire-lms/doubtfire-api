class ExtensionComment < TaskComment

  belongs_to :assessor, class_name: 'User'

  def serialize(user)
    json = super(user)
    json[:granted] = extension_granted
    json[:assessed] = date_extension_assessed.present?
    json[:date_assessed] = date_extension_assessed
    json
  end

  def assessed?
    self.date_extension_assessed.present?
  end

  def assess_extension(user, granted)
    if self.assessed?
      self.errors[:extension] << 'has already been assessed'
      return false
    end

    self.assessor = user
    self.date_extension_assessed = Time.zone.now
    self.extension_granted = granted && self.task.can_apply_for_extension?

    if self.extension_granted
      self.task.grant_extension
    elsif ! self.task.can_apply_for_extension? && granted
      errors[:extension] << 'cannot be granted as deadline has been reached'
      self.task.add_text_comment(user, 'No additional extensions can be granted for this task as the task deadline has been reached')
    end

    save!
  end
end
