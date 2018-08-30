class UpdateQualityDefault < ActiveRecord::Migration
  def change
    change_column_default :tasks, :quality_pts, -1
  end
end
