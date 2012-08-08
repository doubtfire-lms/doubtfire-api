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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120808141243) do

  create_table "logins", :force => true do |t|
    t.datetime "timestamp"
    t.integer  "user_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "logins", ["user_id"], :name => "index_logins_on_user_id"

  create_table "project_convenors", :force => true do |t|
    t.integer  "project_template_id"
    t.integer  "user_id"
    t.datetime "created_at",          :null => false
    t.datetime "updated_at",          :null => false
  end

  create_table "project_statuses", :force => true do |t|
    t.decimal  "health"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  create_table "project_templates", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "projects", :force => true do |t|
    t.integer  "project_status_id"
    t.integer  "project_template_id"
    t.integer  "team_membership_id"
    t.string   "project_role"
    t.datetime "created_at",          :null => false
    t.datetime "updated_at",          :null => false
  end

  add_index "projects", ["project_status_id"], :name => "index_projects_on_project_status_id"
  add_index "projects", ["project_template_id"], :name => "index_projects_on_project_template_id"
  add_index "projects", ["team_membership_id"], :name => "index_projects_on_team_membership_id"

  create_table "sign_in_log_entries", :force => true do |t|
    t.datetime "time_stamp"
    t.integer  "user_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "sign_in_log_entries", ["user_id"], :name => "index_sign_in_log_entries_on_user_id"

  create_table "task_statuses", :force => true do |t|
    t.string   "name"
    t.string   "description"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table "task_submissions", :force => true do |t|
    t.datetime "submission_time"
    t.datetime "assessment_time"
    t.string   "outcome"
    t.integer  "task_id"
    t.datetime "created_at",      :null => false
    t.datetime "updated_at",      :null => false
  end

  add_index "task_submissions", ["task_id"], :name => "index_task_submissions_on_task_id"

  create_table "task_templates", :force => true do |t|
    t.integer  "project_template_id"
    t.string   "name"
    t.string   "description"
    t.decimal  "weighting"
    t.boolean  "required"
    t.datetime "recommended_completion_date"
    t.datetime "created_at",                  :null => false
    t.datetime "updated_at",                  :null => false
  end

  add_index "task_templates", ["project_template_id"], :name => "index_task_templates_on_project_template_id"

  create_table "tasks", :force => true do |t|
    t.integer  "task_template_id"
    t.integer  "project_id"
    t.integer  "task_status_id"
    t.boolean  "awaiting_signoff"
    t.datetime "created_at",       :null => false
    t.datetime "updated_at",       :null => false
    t.date     "completion_date"
  end

  add_index "tasks", ["project_id"], :name => "index_tasks_on_project_id"
  add_index "tasks", ["task_status_id"], :name => "index_tasks_on_task_status_id"
  add_index "tasks", ["task_template_id"], :name => "index_tasks_on_task_template_id"

  create_table "team_memberships", :force => true do |t|
    t.integer  "user_id"
    t.integer  "team_id"
    t.integer  "project_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "team_memberships", ["project_id"], :name => "index_team_memberships_on_project_id"
  add_index "team_memberships", ["team_id"], :name => "index_team_memberships_on_team_id"
  add_index "team_memberships", ["user_id"], :name => "index_team_memberships_on_user_id"

  create_table "teams", :force => true do |t|
    t.integer  "project_template_id"
    t.integer  "user_id"
    t.string   "meeting_day"
    t.string   "meeting_time"
    t.string   "meeting_location"
    t.datetime "created_at",          :null => false
    t.datetime "updated_at",          :null => false
  end

  add_index "teams", ["project_template_id"], :name => "index_teams_on_project_template_id"
  add_index "teams", ["user_id"], :name => "index_teams_on_user_id"

  create_table "users", :force => true do |t|
    t.string   "email",                  :default => "", :null => false
    t.string   "encrypted_password",     :default => "", :null => false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          :default => 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                             :null => false
    t.datetime "updated_at",                             :null => false
    t.string   "first_name"
    t.string   "last_name"
    t.string   "system_role"
    t.string   "username"
    t.string   "nickname"
  end

end
