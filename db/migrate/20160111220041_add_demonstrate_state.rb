class AddDemonstrateState < ActiveRecord::Migration
  def change
    # if the other status are there...
    if TaskStatus.complete && TaskStatus.all.count == 9
      TaskStatus.create(name:  "Demonstrate", description:  "Your work looks good, demonstrate it to your tutor to complete.")
    end

    if TaskStatus.not_started.name == "Not Submitted"
      ns = TaskStatus.not_started
      ns.name = "Not Started"
      ns.description = "You have not yet started this task."
      ns.save!
    end
  end
end
