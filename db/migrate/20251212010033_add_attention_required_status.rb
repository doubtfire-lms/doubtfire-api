class AddAttentionRequiredStatus < ActiveRecord::Migration[8.0]
  def change
    if TaskStatus.where(name: 'Attention Required').count < 1
      TaskStatus.create name: "Attention Required", description: "This task needs to be discussed with your tutor so that you can get back on track."
    end
  end
end
