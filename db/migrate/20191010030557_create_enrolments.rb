class CreateEnrolments < ActiveRecord::Migration
  def change
    create_table :enrolments do |t|

      t.timestamps null: false
    end
    add_reference :enrolments, :project, null: false, foreign_key: true, index: true
    add_reference :enrolments, :tutorial, null: false, foreign_key: true, index: true
  end
end
