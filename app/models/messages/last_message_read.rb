class LastMessageRead < ApplicationRecord
  belongs_to :user, optional: false
  belongs_to :message, optional: false

  validate :ensure_only_one_per_user_per_scope, on: :create

  # todo: on update validate that the scope has not changed

  private

  def ensure_only_one_per_user_per_scope
    # all contexts must be able to return the messages they contain
    if is_system_message
      # System messages do not have a context - only one place where they are read... so only one of these ever for a user
      errors.add(:user, "User has already got a last read system message") unless LastMessageRead.where(user: user, context_id: nil).empty?
    else
      # It is an error, unless there are NO last message read in this scope
      errors.add(:user, "User has already got a last read message in this scope") unless message.context_object.comments.joins(:last_message_reads).where(last_message_reads: { user: user }).empty?
    end
  end
end
