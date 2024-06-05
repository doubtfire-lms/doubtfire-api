# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_06_03_020127) do
  create_table "activity_types", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["abbreviation"], name: "index_activity_types_on_abbreviation", unique: true
    t.index ["name"], name: "index_activity_types_on_name", unique: true
  end

  create_table "auth_tokens", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "auth_token_expiry", null: false
    t.bigint "user_id"
    t.string "authentication_token", null: false
    t.index ["user_id"], name: "index_auth_tokens_on_user_id"
  end

  create_table "breaks", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "start_date", null: false
    t.integer "number_of_weeks", null: false
    t.bigint "teaching_period_id"
    t.index ["teaching_period_id"], name: "index_breaks_on_teaching_period_id"
  end

  create_table "campuses", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.integer "mode", null: false
    t.string "abbreviation", null: false
    t.boolean "active", null: false
    t.index ["abbreviation"], name: "index_campuses_on_abbreviation", unique: true
    t.index ["active"], name: "index_campuses_on_active"
    t.index ["name"], name: "index_campuses_on_name", unique: true
  end

  create_table "comments_read_receipts", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "task_comment_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_comment_id", "user_id"], name: "index_comments_read_receipts_on_task_comment_id_and_user_id", unique: true
    t.index ["task_comment_id"], name: "index_comments_read_receipts_on_task_comment_id"
    t.index ["user_id"], name: "index_comments_read_receipts_on_user_id"
  end

  create_table "discussion_comments", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "time_started"
    t.datetime "time_completed"
    t.integer "number_of_prompts"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "group_memberships", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "group_id"
    t.bigint "project_id"
    t.boolean "active", default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["project_id"], name: "index_group_memberships_on_project_id"
  end

  create_table "group_sets", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "unit_id"
    t.string "name"
    t.boolean "allow_students_to_create_groups", default: true
    t.boolean "allow_students_to_manage_groups", default: true
    t.boolean "keep_groups_in_same_class", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "capacity"
    t.boolean "locked", default: false, null: false
    t.index ["unit_id"], name: "index_group_sets_on_unit_id"
  end

  create_table "group_submissions", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "group_id"
    t.string "notes"
    t.bigint "submitted_by_project_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.bigint "task_definition_id"
    t.index ["group_id"], name: "index_group_submissions_on_group_id"
    t.index ["submitted_by_project_id"], name: "index_group_submissions_on_submitted_by_project_id"
    t.index ["task_definition_id"], name: "index_group_submissions_on_task_definition_id"
  end

  create_table "groups", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "group_set_id"
    t.bigint "tutorial_id"
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "capacity_adjustment", default: 0, null: false
    t.boolean "locked", default: false, null: false
    t.index ["group_set_id"], name: "index_groups_on_group_set_id"
    t.index ["tutorial_id"], name: "index_groups_on_tutorial_id"
  end

  create_table "learning_outcome_task_links", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.text "description"
    t.integer "rating"
    t.bigint "task_definition_id"
    t.bigint "task_id"
    t.bigint "learning_outcome_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["learning_outcome_id"], name: "learning_outcome_task_links_lo_index"
    t.index ["task_definition_id"], name: "index_learning_outcome_task_links_on_task_definition_id"
    t.index ["task_id"], name: "index_learning_outcome_task_links_on_task_id"
  end

  create_table "learning_outcomes", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "unit_id"
    t.integer "ilo_number"
    t.string "name"
    t.string "description", limit: 4096
    t.string "abbreviation"
    t.index ["unit_id"], name: "index_learning_outcomes_on_unit_id"
  end

  create_table "logins", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "timestamp"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_logins_on_user_id"
  end

  create_table "overseer_assessments", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "submission_timestamp", null: false
    t.string "result_task_status"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id", "submission_timestamp"], name: "index_overseer_assessments_on_task_id_and_submission_timestamp", unique: true
    t.index ["task_id"], name: "index_overseer_assessments_on_task_id"
  end

  create_table "overseer_images", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "tag", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "pulled_image_text"
    t.integer "pulled_image_status"
    t.datetime "last_pulled_date"
  end

  create_table "projects", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "unit_id"
    t.string "project_role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "started"
    t.string "progress"
    t.string "status"
    t.string "task_stats"
    t.boolean "enrolled", default: true
    t.integer "target_grade", default: 0
    t.boolean "compile_portfolio", default: false
    t.date "portfolio_production_date"
    t.bigint "user_id"
    t.integer "grade", default: 0
    t.string "grade_rationale", limit: 4096
    t.bigint "campus_id"
    t.integer "submitted_grade"
    t.boolean "uses_draft_learning_summary", default: false, null: false
    t.boolean "portfolio_auto_generated", default: false, null: false
    t.integer "portfolio_generation_pid"
    t.index ["campus_id"], name: "index_projects_on_campus_id"
    t.index ["enrolled"], name: "index_projects_on_enrolled"
    t.index ["unit_id"], name: "index_projects_on_unit_id"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "roles", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "task_comments", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.string "comment", limit: 4096
    t.datetime "created_at", null: false
    t.bigint "recipient_id"
    t.string "content_type"
    t.string "attachment_extension"
    t.bigint "discussion_comment_id"
    t.string "type"
    t.datetime "time_discussion_started"
    t.datetime "time_discussion_completed"
    t.integer "number_of_prompts"
    t.datetime "date_extension_assessed"
    t.boolean "extension_granted"
    t.bigint "assessor_id"
    t.bigint "task_status_id"
    t.integer "extension_weeks"
    t.string "extension_response"
    t.bigint "reply_to_id"
    t.bigint "overseer_assessment_id"
    t.integer "test_attempt_id"
    t.index ["assessor_id"], name: "index_task_comments_on_assessor_id"
    t.index ["discussion_comment_id"], name: "index_task_comments_on_discussion_comment_id"
    t.index ["overseer_assessment_id"], name: "index_task_comments_on_overseer_assessment_id"
    t.index ["recipient_id"], name: "fk_rails_1dbb49165b"
    t.index ["reply_to_id"], name: "index_task_comments_on_reply_to_id"
    t.index ["task_id"], name: "index_task_comments_on_task_id"
    t.index ["task_status_id"], name: "index_task_comments_on_task_status_id"
    t.index ["test_attempt_id"], name: "index_task_comments_on_test_attempt_id"
    t.index ["user_id"], name: "index_task_comments_on_user_id"
  end

  create_table "task_definitions", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "unit_id"
    t.string "name"
    t.string "description", limit: 4096
    t.decimal "weighting", precision: 10
    t.datetime "target_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "abbreviation"
    t.string "upload_requirements", limit: 4096
    t.integer "target_grade", default: 0
    t.boolean "restrict_status_updates", default: false
    t.string "plagiarism_report_url"
    t.boolean "plagiarism_updated", default: false
    t.integer "plagiarism_warn_pct", default: 50
    t.bigint "group_set_id"
    t.datetime "due_date"
    t.datetime "start_date", null: false
    t.boolean "is_graded", default: false
    t.integer "max_quality_pts", default: 0
    t.bigint "tutorial_stream_id"
    t.boolean "assessment_enabled", default: false
    t.bigint "overseer_image_id"
    t.string "tii_group_id"
    t.string "moss_language"
    t.boolean "scorm_enabled", default: false
    t.boolean "scorm_allow_review", default: false
    t.boolean "scorm_time_delay_enabled", default: false
    t.integer "scorm_attempt_limit"
    t.index ["group_set_id"], name: "index_task_definitions_on_group_set_id"
    t.index ["overseer_image_id"], name: "index_task_definitions_on_overseer_image_id"
    t.index ["tutorial_stream_id"], name: "index_task_definitions_on_tutorial_stream_id"
    t.index ["unit_id"], name: "index_task_definitions_on_unit_id"
  end

  create_table "task_engagements", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "engagement_time"
    t.string "engagement"
    t.bigint "task_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_task_engagements_on_task_id"
  end

  create_table "task_pins", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id", "user_id"], name: "index_task_pins_on_task_id_and_user_id", unique: true
    t.index ["task_id"], name: "index_task_pins_on_task_id"
    t.index ["user_id"], name: "fk_rails_915df186ed"
  end

  create_table "task_similarities", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "task_id"
    t.bigint "other_task_id"
    t.integer "pct"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "plagiarism_report_url"
    t.boolean "flagged", default: false
    t.string "type"
    t.bigint "tii_submission_id"
    t.index ["other_task_id"], name: "index_task_similarities_on_other_task_id"
    t.index ["task_id"], name: "index_task_similarities_on_task_id"
    t.index ["tii_submission_id"], name: "index_task_similarities_on_tii_submission_id"
  end

  create_table "task_statuses", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "task_submissions", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "submission_time"
    t.datetime "assessment_time"
    t.string "outcome"
    t.bigint "task_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "assessor_id"
    t.index ["assessor_id"], name: "index_task_submissions_on_assessor_id"
    t.index ["task_id"], name: "index_task_submissions_on_task_id"
  end

  create_table "tasks", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "task_definition_id"
    t.bigint "project_id"
    t.bigint "task_status_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "completion_date"
    t.string "portfolio_evidence"
    t.boolean "include_in_portfolio", default: true
    t.datetime "file_uploaded_at"
    t.bigint "group_submission_id"
    t.integer "contribution_pct", default: 100
    t.integer "times_assessed", default: 0
    t.datetime "submission_date"
    t.datetime "assessment_date"
    t.integer "grade"
    t.integer "contribution_pts", default: 3
    t.integer "quality_pts", default: -1
    t.integer "extensions", default: 0, null: false
    t.integer "scorm_extensions", default: 0, null: false
    t.index ["group_submission_id"], name: "index_tasks_on_group_submission_id"
    t.index ["project_id", "task_definition_id"], name: "tasks_uniq_proj_task_def", unique: true
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["task_definition_id"], name: "index_tasks_on_task_definition_id"
    t.index ["task_status_id"], name: "index_tasks_on_task_status_id"
  end

  create_table "teaching_periods", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "period", null: false
    t.datetime "start_date", null: false
    t.datetime "end_date", null: false
    t.integer "year", null: false
    t.datetime "active_until", null: false
    t.index ["period", "year"], name: "index_teaching_periods_on_period_and_year", unique: true
  end

  create_table "test_attempts", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_id"
    t.datetime "attempted_time", null: false
    t.boolean "terminated", default: false
    t.boolean "completion_status", default: false
    t.boolean "success_status", default: false
    t.float "score_scaled", default: 0.0
    t.text "cmi_datamodel", default: "{}", null: false
    t.index ["task_id"], name: "index_test_attempts_on_task_id"
  end

  create_table "tii_actions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "entity_type"
    t.bigint "entity_id"
    t.string "type"
    t.boolean "complete", default: false, null: false
    t.integer "retries", default: 0, null: false
    t.datetime "last_run"
    t.datetime "complete_at"
    t.boolean "retry", default: true, null: false
    t.integer "error_code"
    t.text "custom_error_message"
    t.text "log"
    t.string "params", limit: 1024, default: "{}"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["complete"], name: "index_tii_actions_on_complete"
    t.index ["entity_type", "entity_id"], name: "index_tii_actions_on_entity"
    t.index ["retry"], name: "index_tii_actions_on_retry"
  end

  create_table "tii_group_attachments", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_definition_id", null: false
    t.string "filename", null: false
    t.string "group_attachment_id"
    t.string "file_sha1_digest"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_definition_id"], name: "index_tii_group_attachments_on_task_definition_id"
  end

  create_table "tii_submissions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "tii_task_similarity_id"
    t.bigint "submitted_by_user_id", null: false
    t.string "filename", null: false
    t.integer "idx", null: false
    t.string "submission_id"
    t.string "similarity_pdf_id"
    t.datetime "submitted_at"
    t.datetime "similarity_request_at"
    t.integer "status", default: 0, null: false
    t.integer "overall_match_percentage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["submitted_by_user_id"], name: "index_tii_submissions_on_submitted_by_user_id"
    t.index ["task_id"], name: "index_tii_submissions_on_task_id"
    t.index ["tii_task_similarity_id"], name: "index_tii_submissions_on_tii_task_similarity_id"
  end

  create_table "tutorial_enrolments", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "project_id", null: false
    t.bigint "tutorial_id", null: false
    t.index ["project_id"], name: "index_tutorial_enrolments_on_project_id"
    t.index ["tutorial_id", "project_id"], name: "index_tutorial_enrolments_on_tutorial_id_and_project_id", unique: true
    t.index ["tutorial_id"], name: "index_tutorial_enrolments_on_tutorial_id"
  end

  create_table "tutorial_streams", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "activity_type_id", null: false
    t.bigint "unit_id", null: false
    t.index ["abbreviation", "unit_id"], name: "index_tutorial_streams_on_abbreviation_and_unit_id", unique: true
    t.index ["abbreviation"], name: "index_tutorial_streams_on_abbreviation"
    t.index ["activity_type_id"], name: "fk_rails_14ef80da76"
    t.index ["name", "unit_id"], name: "index_tutorial_streams_on_name_and_unit_id", unique: true
    t.index ["unit_id"], name: "index_tutorial_streams_on_unit_id"
  end

  create_table "tutorials", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "unit_id"
    t.string "meeting_day"
    t.string "meeting_time"
    t.string "meeting_location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
    t.bigint "unit_role_id"
    t.string "abbreviation"
    t.integer "capacity", default: -1
    t.bigint "campus_id"
    t.bigint "tutorial_stream_id"
    t.index ["campus_id"], name: "index_tutorials_on_campus_id"
    t.index ["tutorial_stream_id"], name: "index_tutorials_on_tutorial_stream_id"
    t.index ["unit_id"], name: "index_tutorials_on_unit_id"
    t.index ["unit_role_id"], name: "index_tutorials_on_unit_role_id"
  end

  create_table "unit_roles", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "tutorial_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "role_id"
    t.bigint "unit_id"
    t.index ["role_id"], name: "index_unit_roles_on_role_id"
    t.index ["tutorial_id"], name: "index_unit_roles_on_tutorial_id"
    t.index ["unit_id"], name: "index_unit_roles_on_unit_id"
    t.index ["user_id"], name: "index_unit_roles_on_user_id"
  end

  create_table "units", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.string "description", limit: 4096
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
    t.boolean "active", default: true
    t.datetime "last_plagarism_scan"
    t.bigint "teaching_period_id"
    t.bigint "main_convenor_id"
    t.boolean "auto_apply_extension_before_deadline", default: true, null: false
    t.boolean "send_notifications", default: true, null: false
    t.boolean "enable_sync_timetable", default: true, null: false
    t.boolean "enable_sync_enrolments", default: true, null: false
    t.bigint "draft_task_definition_id"
    t.boolean "allow_student_extension_requests", default: true, null: false
    t.integer "extension_weeks_on_resubmit_request", default: 1, null: false
    t.boolean "allow_student_change_tutorial", default: true, null: false
    t.boolean "assessment_enabled", default: true
    t.bigint "overseer_image_id"
    t.datetime "portfolio_auto_generation_date"
    t.string "tii_group_context_id"
    t.index ["draft_task_definition_id"], name: "index_units_on_draft_task_definition_id"
    t.index ["main_convenor_id"], name: "index_units_on_main_convenor_id"
    t.index ["overseer_image_id"], name: "index_units_on_overseer_image_id"
    t.index ["teaching_period_id"], name: "index_units_on_teaching_period_id"
  end

  create_table "users", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "username"
    t.string "nickname"
    t.string "unlock_token"
    t.bigint "role_id", default: 0
    t.boolean "receive_task_notifications", default: true
    t.boolean "receive_feedback_notifications", default: true
    t.boolean "receive_portfolio_notifications", default: true
    t.boolean "opt_in_to_research"
    t.boolean "has_run_first_time_setup", default: false
    t.string "login_id"
    t.string "student_id"
    t.string "tii_eula_version"
    t.datetime "tii_eula_date"
    t.boolean "tii_eula_version_confirmed", default: false, null: false
    t.index ["login_id"], name: "index_users_on_login_id", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  create_table "webcal_unit_exclusions", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.bigint "webcal_id", null: false
    t.bigint "unit_id", null: false
    t.index ["unit_id", "webcal_id"], name: "index_webcal_unit_exclusions_on_unit_id_and_webcal_id", unique: true
    t.index ["unit_id"], name: "index_webcal_unit_exclusions_on_unit_id"
    t.index ["webcal_id"], name: "fk_rails_d5fab02cb7"
  end

  create_table "webcals", charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "guid", limit: 36, null: false
    t.boolean "include_start_dates", default: false, null: false
    t.bigint "user_id"
    t.integer "reminder_time"
    t.string "reminder_unit"
    t.index ["guid"], name: "index_webcals_on_guid", unique: true
    t.index ["user_id"], name: "index_webcals_on_user_id", unique: true
  end

end
