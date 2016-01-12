class AddFailStatus < ActiveRecord::Migration
  def change
    # if the other status are there...
    if TaskStatus.complete && TaskStatus.all.count == 10
      TaskStatus.create(name:  "Fail", description:  "You did not successfully demonstrate the required learning in this task.")
    end
  end
end
