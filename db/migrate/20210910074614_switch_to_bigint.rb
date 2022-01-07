class SwitchToBigint < ActiveRecord::Migration[6.1]
  def change
    remove_foreign_key "breaks", "teaching_periods" if ActiveRecord::Base.connection.foreign_key_exists?(:breaks, :teaching_periods)
    remove_foreign_key "comments_read_receipts", "task_comments" if ActiveRecord::Base.connection.foreign_key_exists?(:comments_read_receipts, :task_comments)
    remove_foreign_key "comments_read_receipts", "users" if ActiveRecord::Base.connection.foreign_key_exists?(:comments_read_receipts, :users)
    remove_foreign_key "overseer_assessments", "tasks" if ActiveRecord::Base.connection.foreign_key_exists?(:overseer_assessments, :tasks)
    remove_foreign_key "projects", "campuses" if ActiveRecord::Base.connection.foreign_key_exists?(:projects, :campuses)
    remove_foreign_key "task_comments", "users", column: "recipient_id" if ActiveRecord::task_comments.connection.foreign_key_exists?(:breaks, :users)
    remove_foreign_key "task_definitions", "tutorial_streams" if ActiveRecord::Base.connection.foreign_key_exists?(:task_definitions, :tutorial_streams)
    remove_foreign_key "task_pins", "tasks" if ActiveRecord::Base.connection.foreign_key_exists?(:task_pins, :tasks)
    remove_foreign_key "task_pins", "users" if ActiveRecord::Base.connection.foreign_key_exists?(:task_pins, :users)
    remove_foreign_key "tutorial_enrolments", "projects" if ActiveRecord::Base.connection.foreign_key_exists?(:tutorial_enrolments, :projects)
    remove_foreign_key "tutorial_enrolments", "tutorials" if ActiveRecord::Base.connection.foreign_key_exists?(:tutorial_enrolments, :tutorials)
    remove_foreign_key "tutorial_streams", "activity_types" if ActiveRecord::Base.connection.foreign_key_exists?(:tutorial_streams, :activity_types)
    remove_foreign_key "tutorial_streams", "units" if ActiveRecord::Base.connection.foreign_key_exists?(:tutorial_streams, :units)
    remove_foreign_key "tutorials", "campuses" if ActiveRecord::Base.connection.foreign_key_exists?(:tutorials, :campuses)
    remove_foreign_key "tutorials", "tutorial_streams" if ActiveRecord::Base.connection.foreign_key_exists?(:tutorials, :tutorial_streams)
    remove_foreign_key "units", "teaching_periods" if ActiveRecord::Base.connection.foreign_key_exists?(:units, :teaching_periods)
    remove_foreign_key "webcal_unit_exclusions", "units" if ActiveRecord::Base.connection.foreign_key_exists?(:webcal_unit_exclusions, :units)
    remove_foreign_key "webcal_unit_exclusions", "webcals" if ActiveRecord::Base.connection.foreign_key_exists?(:webcal_unit_exclusions, :webcals)
    remove_foreign_key "webcals", "users" if ActiveRecord::Base.connection.foreign_key_exists?(:webcals, :users)

    # Change id columns
    change_column :activity_types, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :auth_tokens, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :breaks, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :campuses, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :comments_read_receipts, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :discussion_comments, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :group_memberships, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :group_sets, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :group_submissions, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :groups, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :learning_outcome_task_links, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :learning_outcomes, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :logins, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :overseer_assessments, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :overseer_images, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :plagiarism_match_links, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :projects, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :roles, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :task_comments, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :task_definitions, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :task_engagements, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :task_pins, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :task_statuses, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :task_submissions, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :tasks, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :teaching_periods, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :tutorial_enrolments, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :tutorial_streams, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :tutorials, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :unit_roles, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :units, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :users, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :webcal_unit_exclusions, :id, :bigint, unique: true, null: false, auto_increment: true
    change_column :webcals, :id, :bigint, unique: true, null: false, auto_increment: true

    # Change foreign keys
    change_column :auth_tokens, :user_id, :bigint
    change_column :breaks, :teaching_period_id, :bigint
    change_column :comments_read_receipts, :task_comment_id, :bigint, null: false
    change_column :comments_read_receipts, :user_id, :bigint, null: false
    change_column :group_memberships, :group_id, :bigint
    change_column :group_memberships, :project_id, :bigint
    change_column :group_sets, :unit_id, :bigint
    change_column :group_submissions, :group_id, :bigint
    change_column :group_submissions, :submitted_by_project_id, :bigint
    change_column :group_submissions, :task_definition_id, :bigint
    change_column :groups, :group_set_id, :bigint
    change_column :groups, :tutorial_id, :bigint
    change_column :learning_outcome_task_links, :task_definition_id, :bigint
    change_column :learning_outcome_task_links, :task_id, :bigint
    change_column :learning_outcome_task_links, :learning_outcome_id, :bigint
    change_column :learning_outcomes, :unit_id, :bigint
    change_column :logins, :user_id, :bigint
    change_column :overseer_assessments, :task_id, :bigint
    change_column :plagiarism_match_links, :task_id, :bigint
    change_column :plagiarism_match_links, :other_task_id, :bigint
    change_column :projects, :unit_id, :bigint
    change_column :projects, :user_id, :bigint
    change_column :projects, :campus_id, :bigint
    change_column :task_comments, :task_id, :bigint
    change_column :task_comments, :user_id, :bigint
    change_column :task_comments, :recipient_id, :bigint
    change_column :task_comments, :discussion_comment_id, :bigint
    change_column :task_comments, :assessor_id, :bigint
    change_column :task_comments, :task_status_id, :bigint
    change_column :task_comments, :reply_to_id, :bigint
    change_column :task_comments, :overseer_assessment_id, :bigint
    change_column :task_definitions, :unit_id, :bigint
    change_column :task_definitions, :group_set_id, :bigint
    change_column :task_definitions, :tutorial_stream_id, :bigint
    change_column :task_definitions, :overseer_image_id, :bigint
    change_column :task_engagements, :task_id, :bigint
    change_column :task_pins, :task_id, :bigint
    change_column :task_pins, :user_id, :bigint
    change_column :task_submissions, :task_id, :bigint
    change_column :task_submissions, :assessor_id, :bigint
    change_column :tasks, :task_definition_id, :bigint
    change_column :tasks, :project_id, :bigint
    change_column :tasks, :task_status_id, :bigint
    change_column :tasks, :group_submission_id, :bigint
    change_column :tutorial_enrolments, :project_id, :bigint
    change_column :tutorial_enrolments, :tutorial_id, :bigint
    change_column :tutorial_streams, :activity_type_id, :bigint
    change_column :tutorial_streams, :unit_id, :bigint
    change_column :tutorials, :unit_id, :bigint
    change_column :tutorials, :unit_role_id, :bigint
    change_column :tutorials, :campus_id, :bigint
    change_column :tutorials, :tutorial_stream_id, :bigint
    change_column :unit_roles, :user_id, :bigint
    change_column :unit_roles, :tutorial_id, :bigint
    change_column :unit_roles, :role_id, :bigint
    change_column :unit_roles, :unit_id, :bigint
    change_column :units, :teaching_period_id, :bigint
    change_column :units, :main_convenor_id, :bigint
    change_column :units, :draft_task_definition_id, :bigint
    change_column :units, :overseer_image_id, :bigint
    change_column :users, :role_id, :bigint, default: 0
    change_column :webcal_unit_exclusions, :webcal_id, :bigint, null: false
    change_column :webcal_unit_exclusions, :unit_id, :bigint, null: false
    change_column :webcals, :user_id, :bigint

    # Reinstate indexes (not as foreign keys)
    # add_index :auth_tokens, :user_id
    # add_index :breaks, :teaching_period_id
    # add_index :comments_read_receipts, :task_comment_id
    # add_index :comments_read_receipts, :user_id
    add_index :group_memberships, :group_id
    add_index :group_memberships, :project_id
    # add_index :group_sets, :unit_id
    add_index :group_submissions, :group_id
    add_index :group_submissions, :submitted_by_project_id
    add_index :group_submissions, :task_definition_id
    add_index :groups, :group_set_id
    add_index :groups, :tutorial_id
    # add_index :learning_outcome_task_links, :task_definition_id
    # add_index :learning_outcome_task_links, :task_id
    add_index :learning_outcome_task_links, :learning_outcome_id
    # add_index :learning_outcomes, :unit_id
    # add_index :logins, :user_id
    # add_index :overseer_assessments, :task_id
    # add_index :plagiarism_match_links, :task_id
    # add_index :plagiarism_match_links, :other_task_id
    # add_index :projects, :unit_id
    # add_index :projects, :user_id
    # add_index :projects, :campus_id
    # add_index :task_comments, :task_id
    add_index :task_comments, :user_id
    # add_index :task_comments, :recipient_id
    # add_index :task_comments, :discussion_comment_id
    add_index :task_comments, :assessor_id
    add_index :task_comments, :task_status_id
    # add_index :task_comments, :reply_to_id
    # add_index :task_comments, :overseer_assessment_id
    # add_index :task_definitions, :unit_id
    add_index :task_definitions, :group_set_id
    # add_index :task_definitions, :tutorial_stream_id
    # add_index :task_definitions, :overseer_image_id
    # add_index :task_engagements, :task_id
    add_index :task_pins, :task_id
    # add_index :task_pins, :user_id
    # add_index :task_submissions, :task_id
    add_index :task_submissions, :assessor_id
    # add_index :tasks, :task_definition_id
    # add_index :tasks, :project_id
    # add_index :tasks, :task_status_id
    # add_index :tasks, :group_submission_id
    # add_index :tutorial_enrolments, :project_id
    # add_index :tutorial_enrolments, :tutorial_id
    # add_index :tutorial_streams, :activity_type_id
    # add_index :tutorial_streams, :unit_id
    # add_index :tutorials, :unit_id
    # add_index :tutorials, :unit_role_id
    # add_index :tutorials, :campus_id
    # add_index :tutorials, :tutorial_stream_id
    # add_index :unit_roles, :user_id
    # add_index :unit_roles, :tutorial_id
    # add_index :unit_roles, :role_id
    # add_index :unit_roles, :unit_id
    # add_index :units, :teaching_period_id
    add_index :units, :main_convenor_id
    add_index :units, :draft_task_definition_id
    # add_index :units, :overseer_image_id
    add_index :users, :role_id
    # add_index :webcal_unit_exclusions, :webcal_id
    add_index :webcal_unit_exclusions, :unit_id
    # add_index :webcals, :user_id

    remove_index :learning_outcome_task_links, name: "index_learning_outcome_task_links_on_learning_outcome_id"
  end

end
