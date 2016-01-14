# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160114121503) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "badges", force: true do |t|
    t.string   "name"
    t.text     "description"
    t.string   "large_image_url"
    t.string   "small_image_url"
    t.integer  "sub_task_definition_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "group_memberships", force: true do |t|
    t.integer  "group_id"
    t.integer  "project_id"
    t.boolean  "active",     default: true
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "group_sets", force: true do |t|
    t.integer  "unit_id"
    t.string   "name"
    t.boolean  "allow_students_to_create_groups", default: true
    t.boolean  "allow_students_to_manage_groups", default: true
    t.boolean  "keep_groups_in_same_class",       default: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "group_sets", ["unit_id"], name: "index_group_sets_on_unit_id", using: :btree

  create_table "group_submissions", force: true do |t|
    t.integer  "group_id"
    t.string   "notes"
    t.integer  "submitted_by_project_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "task_definition_id"
  end

  create_table "groups", force: true do |t|
    t.integer  "group_set_id"
    t.integer  "tutorial_id"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "helpdesk_schedules", force: true do |t|
    t.datetime "start_time"
    t.integer  "duration"
    t.integer  "day"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_schedules", ["user_id"], name: "index_helpdesk_schedules_on_user_id", using: :btree

  create_table "learning_outcome_task_links", force: true do |t|
    t.text     "description"
    t.integer  "rating"
    t.integer  "task_definition_id"
    t.integer  "task_id"
    t.integer  "learning_outcome_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "learning_outcome_task_links", ["learning_outcome_id"], name: "learning_outcome_task_links_lo_index", using: :btree
  add_index "learning_outcome_task_links", ["task_definition_id"], name: "index_learning_outcome_task_links_on_task_definition_id", using: :btree
  add_index "learning_outcome_task_links", ["task_id"], name: "index_learning_outcome_task_links_on_task_id", using: :btree

  create_table "learning_outcomes", force: true do |t|
    t.integer "unit_id"
    t.integer "ilo_number"
    t.string  "name"
    t.string  "description"
    t.string  "abbreviation"
  end

  add_index "learning_outcomes", ["unit_id"], name: "index_learning_outcomes_on_unit_id", using: :btree

  create_table "logins", force: true do |t|
    t.datetime "timestamp"
    t.integer  "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "logins", ["user_id"], name: "index_logins_on_user_id", using: :btree

  create_table "plagiarism_match_links", force: true do |t|
    t.integer  "task_id"
    t.integer  "other_task_id"
    t.integer  "pct"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "plagiarism_report_url"
  end

  add_index "plagiarism_match_links", ["other_task_id"], name: "index_plagiarism_match_links_on_other_task_id", using: :btree
  add_index "plagiarism_match_links", ["task_id"], name: "index_plagiarism_match_links_on_task_id", using: :btree

  create_table "projects", force: true do |t|
    t.integer  "unit_id"
    t.string   "project_role"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.boolean  "started"
    t.string   "progress"
    t.string   "status"
    t.string   "task_stats"
    t.boolean  "enrolled",                  default: true
    t.integer  "target_grade",              default: 0
    t.boolean  "compile_portfolio",         default: false
    t.date     "portfolio_production_date"
    t.integer  "max_pct_similar",           default: 0
    t.integer  "tutorial_id"
    t.integer  "user_id"
  end

  add_index "projects", ["enrolled"], name: "index_projects_on_enrolled", using: :btree
  add_index "projects", ["tutorial_id"], name: "index_projects_on_tutorial_id", using: :btree
  add_index "projects", ["unit_id"], name: "index_projects_on_unit_id", using: :btree
  add_index "projects", ["user_id"], name: "index_projects_on_user_id", using: :btree

  create_table "roles", force: true do |t|
    t.string   "name"
    t.text     "description"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "sub_task_definitions", force: true do |t|
    t.string   "name"
    t.text     "description"
    t.integer  "badges_id"
    t.integer  "task_definitions_id"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.boolean  "required",            default: false, null: false
  end

  add_index "sub_task_definitions", ["badges_id"], name: "index_sub_task_definitions_on_badges_id", using: :btree

  create_table "sub_tasks", force: true do |t|
    t.datetime "completion_date"
    t.integer  "sub_task_definition_id"
    t.integer  "task_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "task_comments", force: true do |t|
    t.integer  "task_id",                 null: false
    t.integer  "user_id",                 null: false
    t.string   "comment",    limit: 2048
    t.datetime "created_at",              null: false
  end

  add_index "task_comments", ["task_id"], name: "index_task_comments_on_task_id", using: :btree

  create_table "task_definitions", force: true do |t|
    t.integer  "unit_id"
    t.string   "name"
    t.string   "description"
    t.decimal  "weighting",                            precision: 10, scale: 0
    t.datetime "target_date"
    t.datetime "created_at",                                                                    null: false
    t.datetime "updated_at",                                                                    null: false
    t.string   "abbreviation"
    t.string   "upload_requirements",     limit: 2048
    t.integer  "target_grade",                                                  default: 0
    t.boolean  "restrict_status_updates",                                       default: false
    t.string   "plagiarism_checks",       limit: 2048
    t.string   "plagiarism_report_url"
    t.boolean  "plagiarism_updated",                                            default: false
    t.integer  "plagiarism_warn_pct",                                           default: 50
    t.integer  "group_set_id"
    t.datetime "due_date"
  end

  add_index "task_definitions", ["unit_id"], name: "index_task_definitions_on_unit_id", using: :btree

  create_table "task_engagements", force: true do |t|
    t.datetime "engagement_time"
    t.string   "engagement"
    t.integer  "task_id"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "task_engagements", ["task_id"], name: "index_task_engagements_on_task_id", using: :btree

  create_table "task_statuses", force: true do |t|
    t.string   "name"
    t.string   "description"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "task_submissions", force: true do |t|
    t.datetime "submission_time"
    t.datetime "assessment_time"
    t.string   "outcome"
    t.integer  "task_id"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.integer  "assessor_id"
  end

  add_index "task_submissions", ["task_id"], name: "index_task_submissions_on_task_id", using: :btree

  create_table "tasks", force: true do |t|
    t.integer  "task_definition_id"
    t.integer  "project_id"
    t.integer  "task_status_id"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.date     "completion_date"
    t.string   "portfolio_evidence"
    t.boolean  "include_in_portfolio", default: true
    t.datetime "file_uploaded_at"
    t.integer  "max_pct_similar",      default: 0
    t.integer  "group_submission_id"
    t.integer  "contribution_pct",     default: 100
    t.integer  "times_assessed",       default: 0
    t.datetime "submission_date"
    t.datetime "assessment_date"
  end

  add_index "tasks", ["group_submission_id"], name: "index_tasks_on_group_submission_id", using: :btree
  add_index "tasks", ["project_id"], name: "index_tasks_on_project_id", using: :btree
  add_index "tasks", ["task_definition_id"], name: "index_tasks_on_task_definition_id", using: :btree
  add_index "tasks", ["task_status_id"], name: "index_tasks_on_task_status_id", using: :btree

  create_table "tutorials", force: true do |t|
    t.integer  "unit_id"
    t.string   "meeting_day"
    t.string   "meeting_time"
    t.string   "meeting_location"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.string   "code"
    t.integer  "unit_role_id"
    t.string   "abbreviation"
  end

  add_index "tutorials", ["unit_id"], name: "index_tutorials_on_unit_id", using: :btree
  add_index "tutorials", ["unit_role_id"], name: "index_tutorials_on_unit_role_id", using: :btree

  create_table "unit_roles", force: true do |t|
    t.integer  "user_id"
    t.integer  "tutorial_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.integer  "role_id"
    t.integer  "unit_id"
  end

  add_index "unit_roles", ["role_id"], name: "index_unit_roles_on_role_id", using: :btree
  add_index "unit_roles", ["tutorial_id"], name: "index_unit_roles_on_tutorial_id", using: :btree
  add_index "unit_roles", ["unit_id"], name: "index_unit_roles_on_unit_id", using: :btree
  add_index "unit_roles", ["user_id"], name: "index_unit_roles_on_user_id", using: :btree

  create_table "units", force: true do |t|
    t.string   "name"
    t.string   "description"
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.string   "code"
    t.boolean  "active",              default: true
    t.datetime "last_plagarism_scan"
  end

  create_table "user_roles", force: true do |t|
    t.integer  "user_id"
    t.integer  "role_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "user_roles", ["role_id"], name: "index_user_roles_on_role_id", using: :btree
  add_index "user_roles", ["user_id"], name: "index_user_roles_on_user_id", using: :btree

  create_table "users", force: true do |t|
    t.string   "email",                           default: "",    null: false
    t.string   "encrypted_password",              default: "",    null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                   default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.string   "first_name"
    t.string   "last_name"
    t.string   "username"
    t.string   "nickname"
    t.string   "authentication_token"
    t.string   "unlock_token"
    t.datetime "auth_token_expiry"
    t.integer  "role_id",                         default: 0
    t.boolean  "receive_task_notifications",      default: true
    t.boolean  "receive_feedback_notifications",  default: true
    t.boolean  "receive_portfolio_notifications", default: true
    t.boolean  "opt_in_to_research"
    t.boolean  "has_run_first_time_setup",        default: false
  end

  add_index "users", ["authentication_token"], name: "index_users_on_authentication_token", unique: true, using: :btree

end
