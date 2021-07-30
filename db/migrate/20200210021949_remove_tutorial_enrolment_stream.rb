class RemoveTutorialEnrolmentStream < ActiveRecord::Migration
  def change
    remove_index :tutorial_enrolments, name: "index_tutorial_enrolments_on_tutorial_stream_id_and_project_id"
    remove_reference :tutorial_enrolments, :tutorial_stream, foreign_key: true, index: true
  end
end
