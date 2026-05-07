class AddCommunicationsFeat < ActiveRecord::Migration[8.0]
  def change
    create_table :communication_sets do |t|
      t.references :unit, null: false
      t.string :name
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :communication_rules do |t|
      t.references :communication_set, null: false

      t.integer :position, null: false, default: 0
      t.string :name
      # AND | OR
      t.string :operator # AND | OR

      t.boolean :send_log_to_convenors, null: false, default: false

      t.boolean :active, null: false, default: true

      t.timestamps
    end

    create_table :communication_conditions do |t|
      t.string :type, null: false
      t.references :communication, null: false

      # TargetGradeCondition
      t.integer :target_grade
      # t.string :target_grade_comparison # gt|gte|lt|lte|notequal|equal

      # TaskDefinitionStatusCondition
      t.references :task_definition
      t.json :task_statuses
      # t.string :task_status_comparison # equal|notequal

      # LoginStatusCondition
      t.datetime :last_sign_in_at
      # t.string :last_sign_in_comparison # before|after

      # TutorialEnrolmentCondition
      t.references :tutorial
      # t.string :tutorial_comparison # enrolled|notenrolled

      # TutorialStreamEnrolmentCondition
      t.references :tutorial_stream
      # t.string :tutorial_stream_comparison # enrolled|notenrolled

      # CampusCondition
      t.references :campus
      # t.string :campus_comparison # enrolled|notenrolled

      # TaskStatusCountCondition
      t.integer :task_status_count
      t.integer :task_target_grade

      t.string :operator, null: false

      t.timestamps
    end

    create_table :communication_actions do |t|
      t.string :type, null: false
      t.references :communication_rule, null: false

      # EmailStudentAction / EmailStaffAction
      t.string :subject
      t.text :body

      # EmailStaffAction
      t.boolean :email_tutors, null: false, default: false
      t.boolean :email_convenors, null: false, default: false

      # ChangeTargetGradeAction
      t.integer :target_grade

      t.timestamps
    end

    add_index :communication_actions, :type
    add_index :communication_conditions, :type
  end
end
