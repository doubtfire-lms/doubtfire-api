class AddRediscussStatus < ActiveRecord::Migration[8.0]
  DESCRIPTION = "You attempted to discuss this task, but it was not adequate. " \
                "Brush up your knowledge and return for another discussion " \
                "to get the task signed off.".freeze

  def up
    status = TaskStatus.find_by(id: 15) || TaskStatus.find_by(name: "Rediscuss")

    if status
      status.update!(name: "Rediscuss", description: DESCRIPTION)
    else
      TaskStatus.create!(id: 15, name: "Rediscuss", description: DESCRIPTION)
    end

    Rails.cache.delete("task_statuses/15")
  end

  def down
    status = TaskStatus.find_by(id: 15, name: "Rediscuss")
    status&.destroy!
    Rails.cache.delete("task_statuses/15")
  end
end
