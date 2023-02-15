class LastMessageRead < ApplicationRecord
  belongs_to :user, optional: false
  belongs_to :message, optional: false

  validate :ensure_only_one_per_user_per_scope

  private

  def ensure_only_one_per_user_per_scope
    # all contexts must be able to return the messages they contain
    if message.context_object.present? && message.context_object.comments.joins(:last_message_reads).where(last_message_reads: {user: user}).count > 1
      errors.add(:user, "User has already got a last read message in this scope")
    end
  end
end
