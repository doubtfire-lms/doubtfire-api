class UpdateQualityDefault < ActiveRecord::Migration[4.2]
  def change
    change_column_default :tasks, :quality_pts, -1
  end
end
