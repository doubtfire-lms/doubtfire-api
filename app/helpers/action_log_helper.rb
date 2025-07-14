module ActionLogHelper
  def log_action(name, **props)
    return if current_user.nil?
    ActionLog.create!(
      user: current_user,
      name: name,
      properties: props
    )
  end
end
