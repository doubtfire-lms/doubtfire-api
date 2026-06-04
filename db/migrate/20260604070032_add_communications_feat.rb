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

    create_table :communication_set_schedules do |t|
      t.references :communication_set, null: false
      t.string :name
      t.boolean :active, null: false, default: true

      # Anchor the schedule to the unit's teaching calendar. The actual start
      # datetime is resolved through Unit#date_for_week_and_day.
      t.integer :anchor_week, null: false
      t.string :anchor_day, null: false
      t.integer :hour, null: false, default: 8
      t.integer :minute, null: false, default: 0
      t.string :timezone, null: false, default: "UTC"

      # Canonical recurrence settings to hydrate IceCube rules from.
      t.string :recurrence, null: false, default: "none"
      t.integer :interval, null: false, default: 1

      # Optional limits for recurring schedules.
      t.integer :repeat_count
      t.datetime :until_at

      # Serialized payload to rebuild an IceCube schedule without guessing.
      t.json :ice_cube_schedule

      # Derived state for the worker that enqueues due communication runs.
      t.datetime :next_run_at
      t.datetime :last_run_at
      t.datetime :last_enqueued_at

      t.timestamps
    end

    add_index :communication_actions, :type
    add_index :communication_conditions, :type
    add_index :communication_set_schedules, [:active, :next_run_at]
  end
end
