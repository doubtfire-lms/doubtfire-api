class FailStatusChange < ActiveRecord::Migration[7.0]
  def up
    TaskStatus.where(name: "Fail").update_all(name: "Needs Improvement")
    TaskStatusComment.where(comment: "Fail").update_all(comment: "Needs Improvement")
  end

  def down
    TaskStatus.where(name: "Needs Improvement").update_all(name: "Fail")
    TaskStatusComment.where(comment: "Needs Improvement").update_all(comment: "Fail")
  end
end
