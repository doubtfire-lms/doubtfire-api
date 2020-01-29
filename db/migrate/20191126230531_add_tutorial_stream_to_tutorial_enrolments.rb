class AddTutorialStreamToTutorialEnrolments < ActiveRecord::Migration
  def change
    add_reference :tutorial_enrolments, :tutorial_stream, foreign_key: true, index: true
    add_index :tutorial_enrolments, [:tutorial_stream_id, :project_id], unique: true
  end
end
