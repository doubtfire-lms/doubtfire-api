class CreateTutorialEnrolments < ActiveRecord::Migration
  def change
    create_table :tutorial_enrolments do |t|

      t.timestamps null: false
    end
    add_reference :tutorial_enrolments, :project, null: false, foreign_key: true, index: true
    add_reference :tutorial_enrolments, :tutorial, null: false, foreign_key: true, index: true
    add_index :tutorial_enrolments, [:tutorial_id, :project_id], unique: true
  end
end
