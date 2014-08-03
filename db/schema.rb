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

ActiveRecord::Schema.define(version: 20140803232423) do

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

  create_table "helpdesk_schedules", force: true do |t|
    t.datetime "start_time"
    t.integer  "duration"
    t.integer  "day"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "helpdesk_schedules", ["user_id"], name: "index_helpdesk_schedules_on_user_id", using: :btree

  create_table "logins", force: true do |t|
    t.datetime "timestamp"
    t.integer  "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "logins", ["user_id"], name: "index_logins_on_user_id", using: :btree

  create_table "projects", force: true do |t|
    t.integer  "unit_id"
    t.integer  "unit_role_id"
    t.string   "project_role"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.boolean  "started"
    t.string   "progress"
    t.string   "status"
    t.string   "task_stats"
  end

  add_index "projects", ["unit_id"], name: "index_projects_on_unit_id", using: :btree
  add_index "projects", ["unit_role_id"], name: "index_projects_on_unit_role_id", using: :btree

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

  create_table "task_definitions", force: true do |t|
    t.integer  "unit_id"
    t.string   "name"
    t.string   "description"
    t.decimal  "weighting",                        precision: 10, scale: 0
    t.boolean  "required"
    t.datetime "target_date"
    t.datetime "created_at",                                                null: false
    t.datetime "updated_at",                                                null: false
    t.string   "abbreviation"
    t.string   "upload_requirements", limit: 2048
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
    t.boolean  "awaiting_signoff"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
    t.date     "completion_date"
    t.string   "portfolio_evidence"
  end

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
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "code"
    t.boolean  "active",      default: true
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
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "first_name"
    t.string   "last_name"
    t.string   "username"
    t.string   "nickname"
    t.string   "authentication_token"
    t.string   "unlock_token"
    t.datetime "auth_token_expiry"
    t.integer  "role_id",                default: 0
  end

  add_index "users", ["authentication_token"], name: "index_users_on_authentication_token", unique: true, using: :btree

end
