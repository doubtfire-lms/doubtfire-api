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

ActiveRecord::Schema.define(version: 20200528075434) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "activity_types", force: :cascade do |t|
    t.string   "name",         null: false
    t.string   "abbreviation", null: false
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "activity_types", ["abbreviation"], name: "index_activity_types_on_abbreviation", unique: true, using: :btree
  add_index "activity_types", ["name"], name: "index_activity_types_on_name", unique: true, using: :btree

  create_table "auth_tokens", force: :cascade do |t|
    t.string   "encrypted_authentication_token",    limit: 255, null: false
    t.datetime "auth_token_expiry",                             null: false
    t.integer  "user_id"
    t.string   "encrypted_authentication_token_iv", limit: 255
  end

  add_index "auth_tokens", ["user_id"], name: "index_auth_tokens_on_user_id", using: :btree

  create_table "breaks", force: :cascade do |t|
    t.datetime "start_date",         null: false
    t.integer  "number_of_weeks",    null: false
    t.integer  "teaching_period_id"
  end

  add_index "breaks", ["teaching_period_id"], name: "index_breaks_on_teaching_period_id", using: :btree

  create_table "campuses", force: :cascade do |t|
    t.string  "name",         null: false
    t.integer "mode",         null: false
    t.string  "abbreviation", null: false
    t.boolean "active",       null: false
  end

  add_index "campuses", ["abbreviation"], name: "index_campuses_on_abbreviation", unique: true, using: :btree
  add_index "campuses", ["active"], name: "index_campuses_on_active", using: :btree
  add_index "campuses", ["name"], name: "index_campuses_on_name", unique: true, using: :btree

  create_table "comments_read_receipts", force: :cascade do |t|
    t.integer  "task_comment_id", null: false
    t.integer  "user_id",         null: false
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "comments_read_receipts", ["task_comment_id", "user_id"], name: "index_comments_read_receipts_on_task_comment_id_and_user_id", unique: true, using: :btree
  add_index "comments_read_receipts", ["task_comment_id"], name: "index_comments_read_receipts_on_task_comment_id", using: :btree
  add_index "comments_read_receipts", ["user_id"], name: "index_comments_read_receipts_on_user_id", using: :btree

  create_table "discussion_comments", force: :cascade do |t|
    t.datetime "time_started"
    t.datetime "time_completed"
    t.integer  "number_of_prompts"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  create_table "group_memberships", force: :cascade do |t|
    t.integer  "group_id"
    t.integer  "project_id"
    t.boolean  "active",     default: true
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "group_sets", force: :cascade do |t|
    t.integer  "unit_id"
    t.string   "name",                            limit: 255
    t.boolean  "allow_students_to_create_groups",             default: true
    t.boolean  "allow_students_to_manage_groups",             default: true
    t.boolean  "keep_groups_in_same_class",                   default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "capacity"
  end

  add_index "group_sets", ["unit_id"], name: "index_group_sets_on_unit_id", using: :btree

  create_table "group_submissions", force: :cascade do |t|
    t.integer  "group_id"
    t.string   "notes",                   limit: 255
    t.integer  "submitted_by_project_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "task_definition_id"
  end

  create_table "groups", force: :cascade do |t|
    t.integer  "group_set_id"
    t.integer  "tutorial_id"
    t.string   "name",                limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "capacity_adjustment",             default: 0, null: false
  end

  create_table "learning_outcome_task_links", force: :cascade do |t|
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

  create_table "learning_outcomes", force: :cascade do |t|
    t.integer "unit_id"
    t.integer "ilo_number"
    t.string  "name",         limit: 255
    t.string  "description",  limit: 4096
    t.string  "abbreviation", limit: 255
  end

  add_index "learning_outcomes", ["unit_id"], name: "index_learning_outcomes_on_unit_id", using: :btree

  create_table "logins", force: :cascade do |t|
    t.datetime "timestamp"
    t.integer  "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "logins", ["user_id"], name: "index_logins_on_user_id", using: :btree

  create_table "plagiarism_match_links", force: :cascade do |t|
    t.integer  "task_id"
    t.integer  "other_task_id"
    t.integer  "pct"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "plagiarism_report_url", limit: 255
    t.boolean  "dismissed",                         default: false
  end

  add_index "plagiarism_match_links", ["other_task_id"], name: "index_plagiarism_match_links_on_other_task_id", using: :btree
  add_index "plagiarism_match_links", ["task_id"], name: "index_plagiarism_match_links_on_task_id", using: :btree

  create_table "projects", force: :cascade do |t|
    t.integer  "unit_id"
    t.string   "project_role",              limit: 255
    t.datetime "created_at",                                             null: false
    t.datetime "updated_at",                                             null: false
    t.boolean  "started"
    t.string   "progress",                  limit: 255
    t.string   "status",                    limit: 255
    t.string   "task_stats",                limit: 255
    t.boolean  "enrolled",                               default: true
    t.integer  "target_grade",                           default: 0
    t.boolean  "compile_portfolio",                      default: false
    t.date     "portfolio_production_date"
    t.integer  "max_pct_similar",                        default: 0
    t.integer  "user_id"
    t.integer  "grade",                                  default: 0
    t.string   "grade_rationale",           limit: 4096
    t.integer  "campus_id"
  end

  add_index "projects", ["campus_id"], name: "index_projects_on_campus_id", using: :btree
  add_index "projects", ["enrolled"], name: "index_projects_on_enrolled", using: :btree
  add_index "projects", ["unit_id"], name: "index_projects_on_unit_id", using: :btree
  add_index "projects", ["user_id"], name: "index_projects_on_user_id", using: :btree

  create_table "roles", force: :cascade do |t|
    t.string   "name",        limit: 255
    t.text     "description"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "task_comments", force: :cascade do |t|
    t.integer  "task_id",                                               null: false
    t.integer  "user_id",                                               null: false
    t.string   "comment",                   limit: 4096
    t.datetime "created_at",                                            null: false
    t.boolean  "is_new",                                 default: true
    t.integer  "recipient_id"
    t.string   "content_type"
    t.string   "attachment_extension"
    t.integer  "discussion_comment_id"
    t.string   "type"
    t.datetime "time_discussion_started"
    t.datetime "time_discussion_completed"
    t.integer  "number_of_prompts"
    t.datetime "date_extension_assessed"
    t.boolean  "extension_granted"
    t.integer  "assessor_id"
    t.integer  "task_status_id"
    t.integer  "extension_weeks"
    t.string   "extension_response"
    t.integer  "reply_to_id"
  end

  add_index "task_comments", ["discussion_comment_id"], name: "index_task_comments_on_discussion_comment_id", using: :btree
  add_index "task_comments", ["reply_to_id"], name: "index_task_comments_on_reply_to_id", using: :btree
  add_index "task_comments", ["task_id"], name: "index_task_comments_on_task_id", using: :btree

  create_table "task_definitions", force: :cascade do |t|
    t.integer  "unit_id"
    t.string   "name",                    limit: 255
    t.string   "description",             limit: 4096
    t.decimal  "weighting",                            precision: 10
    t.datetime "target_date",                                                         null: false
    t.datetime "created_at",                                                          null: false
    t.datetime "updated_at",                                                          null: false
    t.string   "abbreviation",            limit: 255
    t.string   "upload_requirements",     limit: 4096
    t.integer  "target_grade",                                        default: 0
    t.boolean  "restrict_status_updates",                             default: false
    t.string   "plagiarism_checks",       limit: 4096
    t.string   "plagiarism_report_url",   limit: 255
    t.boolean  "plagiarism_updated",                                  default: false
    t.integer  "plagiarism_warn_pct",                                 default: 50
    t.integer  "group_set_id"
    t.datetime "due_date"
    t.datetime "start_date",                                                          null: false
    t.boolean  "is_graded",                                           default: false
    t.integer  "max_quality_pts",                                     default: 0
    t.integer  "tutorial_stream_id"
  end

  add_index "task_definitions", ["tutorial_stream_id"], name: "index_task_definitions_on_tutorial_stream_id", using: :btree
  add_index "task_definitions", ["unit_id"], name: "index_task_definitions_on_unit_id", using: :btree

  create_table "task_engagements", force: :cascade do |t|
    t.datetime "engagement_time"
    t.string   "engagement",      limit: 255
    t.integer  "task_id"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "task_engagements", ["task_id"], name: "index_task_engagements_on_task_id", using: :btree

  create_table "task_statuses", force: :cascade do |t|
    t.string   "name",        limit: 255
    t.string   "description", limit: 255
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "task_submissions", force: :cascade do |t|
    t.datetime "submission_time"
    t.datetime "assessment_time"
    t.string   "outcome",         limit: 255
    t.integer  "task_id"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.integer  "assessor_id"
  end

  add_index "task_submissions", ["task_id"], name: "index_task_submissions_on_task_id", using: :btree

  create_table "tasks", force: :cascade do |t|
    t.integer  "task_definition_id"
    t.integer  "project_id"
    t.integer  "task_status_id"
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.date     "completion_date"
    t.string   "portfolio_evidence",   limit: 255
    t.boolean  "include_in_portfolio",             default: true
    t.datetime "file_uploaded_at"
    t.integer  "max_pct_similar",                  default: 0
    t.integer  "group_submission_id"
    t.integer  "contribution_pct",                 default: 100
    t.integer  "times_assessed",                   default: 0
    t.datetime "submission_date"
    t.datetime "assessment_date"
    t.integer  "grade"
    t.integer  "contribution_pts",                 default: 3
    t.integer  "quality_pts",                      default: -1
    t.integer  "extensions",                       default: 0,    null: false
  end

  add_index "tasks", ["group_submission_id"], name: "index_tasks_on_group_submission_id", using: :btree
  add_index "tasks", ["project_id", "task_definition_id"], name: "tasks_uniq_proj_task_def", unique: true, using: :btree
  add_index "tasks", ["project_id"], name: "index_tasks_on_project_id", using: :btree
  add_index "tasks", ["task_definition_id"], name: "index_tasks_on_task_definition_id", using: :btree
  add_index "tasks", ["task_status_id"], name: "index_tasks_on_task_status_id", using: :btree

  create_table "teaching_periods", force: :cascade do |t|
    t.string   "period",       null: false
    t.datetime "start_date",   null: false
    t.datetime "end_date",     null: false
    t.integer  "year",         null: false
    t.datetime "active_until", null: false
  end

  add_index "teaching_periods", ["period", "year"], name: "index_teaching_periods_on_period_and_year", unique: true, using: :btree

  create_table "tutorial_enrolments", force: :cascade do |t|
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.integer  "project_id",  null: false
    t.integer  "tutorial_id", null: false
  end

  add_index "tutorial_enrolments", ["project_id"], name: "index_tutorial_enrolments_on_project_id", using: :btree
  add_index "tutorial_enrolments", ["tutorial_id", "project_id"], name: "index_tutorial_enrolments_on_tutorial_id_and_project_id", unique: true, using: :btree
  add_index "tutorial_enrolments", ["tutorial_id"], name: "index_tutorial_enrolments_on_tutorial_id", using: :btree

  create_table "tutorial_streams", force: :cascade do |t|
    t.string   "name",             null: false
    t.string   "abbreviation",     null: false
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.integer  "activity_type_id", null: false
    t.integer  "unit_id",          null: false
  end

  add_index "tutorial_streams", ["abbreviation", "unit_id"], name: "index_tutorial_streams_on_abbreviation_and_unit_id", unique: true, using: :btree
  add_index "tutorial_streams", ["abbreviation"], name: "index_tutorial_streams_on_abbreviation", using: :btree
  add_index "tutorial_streams", ["name", "unit_id"], name: "index_tutorial_streams_on_name_and_unit_id", unique: true, using: :btree
  add_index "tutorial_streams", ["unit_id"], name: "index_tutorial_streams_on_unit_id", using: :btree

  create_table "tutorials", force: :cascade do |t|
    t.integer  "unit_id"
    t.string   "meeting_day",        limit: 255
    t.string   "meeting_time",       limit: 255
    t.string   "meeting_location",   limit: 255
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.string   "code",               limit: 255
    t.integer  "unit_role_id"
    t.string   "abbreviation",       limit: 255
    t.integer  "capacity",                       default: -1
    t.integer  "campus_id"
    t.integer  "tutorial_stream_id"
  end

  add_index "tutorials", ["campus_id"], name: "index_tutorials_on_campus_id", using: :btree
  add_index "tutorials", ["tutorial_stream_id"], name: "index_tutorials_on_tutorial_stream_id", using: :btree
  add_index "tutorials", ["unit_id"], name: "index_tutorials_on_unit_id", using: :btree
  add_index "tutorials", ["unit_role_id"], name: "index_tutorials_on_unit_role_id", using: :btree

  create_table "unit_roles", force: :cascade do |t|
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

  create_table "units", force: :cascade do |t|
    t.string   "name",                                 limit: 255
    t.string   "description",                          limit: 4096
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "created_at",                                                       null: false
    t.datetime "updated_at",                                                       null: false
    t.string   "code",                                 limit: 255
    t.boolean  "active",                                            default: true
    t.datetime "last_plagarism_scan"
    t.integer  "teaching_period_id"
    t.integer  "main_convenor_id"
    t.boolean  "auto_apply_extension_before_deadline",              default: true, null: false
    t.boolean  "send_notifications",                                default: true, null: false
  end

  add_index "units", ["teaching_period_id"], name: "index_units_on_teaching_period_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email",                           limit: 255, default: "",    null: false
    t.string   "encrypted_password",              limit: 255, default: "",    null: false
    t.string   "reset_password_token",            limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                               default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",              limit: 255
    t.string   "last_sign_in_ip",                 limit: 255
    t.datetime "created_at",                                                  null: false
    t.datetime "updated_at",                                                  null: false
    t.string   "first_name",                      limit: 255
    t.string   "last_name",                       limit: 255
    t.string   "username",                        limit: 255
    t.string   "nickname",                        limit: 255
    t.string   "unlock_token",                    limit: 255
    t.integer  "role_id",                                     default: 0
    t.boolean  "receive_task_notifications",                  default: true
    t.boolean  "receive_feedback_notifications",              default: true
    t.boolean  "receive_portfolio_notifications",             default: true
    t.boolean  "opt_in_to_research"
    t.boolean  "has_run_first_time_setup",                    default: false
    t.string   "login_id"
    t.string   "student_id"
  end

  add_index "users", ["login_id"], name: "index_users_on_login_id", unique: true, using: :btree

  add_foreign_key "auth_tokens", "users"
  add_foreign_key "breaks", "teaching_periods"
  add_foreign_key "comments_read_receipts", "task_comments"
  add_foreign_key "comments_read_receipts", "users"
  add_foreign_key "projects", "campuses"
  add_foreign_key "task_comments", "users", column: "recipient_id"
  add_foreign_key "task_definitions", "tutorial_streams"
  add_foreign_key "tutorial_enrolments", "projects"
  add_foreign_key "tutorial_enrolments", "tutorials"
  add_foreign_key "tutorial_streams", "activity_types"
  add_foreign_key "tutorial_streams", "units"
  add_foreign_key "tutorials", "campuses"
  add_foreign_key "tutorials", "tutorial_streams"
  add_foreign_key "units", "teaching_periods"
end
