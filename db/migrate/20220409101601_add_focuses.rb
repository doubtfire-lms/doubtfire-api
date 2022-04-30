class AddFocuses < ActiveRecord::Migration[7.0]
  def change
    create_table :focuses do |t|
      t.string      :title,           null: false
      t.string      :description,     null: false
      t.integer     :color,           null: false, default: 0

      t.references  :unit,            null: false

      t.timestamps                    null: false
    end

    create_table :project_focuses do |t|
      t.references :project,         null: false
      t.references :focus,           null: false

      t.boolean    :current,         null: false, default: false
      t.integer    :grade_achieved,  default: nil

      t.timestamps                   null: false
    end

    create_table :task_definition_required_focuses do |t|
      t.references :task_definition, null: false
      t.references :focus,           null: false

      t.timestamps                   null: false
    end

    create_table :focus_criteria do |t|
      t.references  :focus

      t.integer     :grade,         null:false, default: 0
      t.string      :description,   null:false, default: ''
    end

    change_table :task_comments do |t|
      t.references  :focus

      t.integer     :focus_understanding, null:false, default: 0
      t.integer     :task_shows_focus,    null:false, default: 0
      t.boolean     :move_on,             null:false, default: false

      t.integer     :grade_achieved,      null:true
      t.integer     :previous_grade,      null:true
    end
  end
end
