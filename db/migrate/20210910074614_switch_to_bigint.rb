class SwitchToBigint < ActiveRecord::Migration[6.1]
  def change
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
  end
end
