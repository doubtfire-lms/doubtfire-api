class ChangeTargetGradeAction < CommunicationAction
  validates :target_grade, presence: true
end
