class EnsureTaskAlignmentRatingNonZero < ActiveRecord::Migration
  def change
    LearningOutcomeTaskLink.where(rating: 0).update_all(rating: 1)
  end
end
