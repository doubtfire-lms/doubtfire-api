class FocusActivateComment < TaskComment
  validates :focus, presence: true

  before_create do
    self.content_type = :focus_change
  end
end
