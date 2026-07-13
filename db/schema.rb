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

ActiveRecord::Schema[8.0].define(version: 2026_07_09_014859) do
  create_table "activity_types", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["abbreviation"], name: "index_activity_types_on_abbreviation", unique: true
    t.index ["name"], name: "index_activity_types_on_name", unique: true
  end

  create_table "auth_tokens", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "auth_token_expiry", null: false
    t.bigint "user_id"
    t.string "authentication_token", null: false
    t.integer "token_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_type"], name: "index_auth_tokens_on_token_type"
    t.index ["user_id"], name: "index_auth_tokens_on_user_id"
  end

  create_table "breaks", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "start_date", null: false
    t.integer "number_of_weeks", null: false
    t.bigint "teaching_period_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["teaching_period_id"], name: "index_breaks_on_teaching_period_id"
  end

  create_table "campuses", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name", null: false
    t.integer "mode", null: false
    t.string "abbreviation", null: false
    t.boolean "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "timezone"
    t.index ["abbreviation"], name: "index_campuses_on_abbreviation", unique: true
    t.index ["active"], name: "index_campuses_on_active"
    t.index ["name"], name: "index_campuses_on_name", unique: true
  end

  create_table "chip_usages", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "feedback_chip_id", null: false
    t.bigint "tutor_id", null: false
    t.integer "usage_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feedback_chip_id"], name: "index_chip_usages_on_feedback_chip_id"
    t.index ["tutor_id"], name: "index_chip_usages_on_tutor_id"
  end

  create_table "comments_read_receipts", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_comment_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_comment_id", "user_id"], name: "index_comments_read_receipts_on_task_comment_id_and_user_id", unique: true
    t.index ["task_comment_id"], name: "index_comments_read_receipts_on_task_comment_id"
    t.index ["user_id"], name: "index_comments_read_receipts_on_user_id"
  end

  create_table "communication_actions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "type", null: false
    t.bigint "communication_rule_id", null: false
    t.string "subject"
    t.text "body"
    t.boolean "email_tutors", default: false, null: false
    t.boolean "email_convenors", default: false, null: false
    t.integer "target_grade"
    t.bigint "task_definition_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["communication_rule_id"], name: "index_communication_actions_on_communication_rule_id"
    t.index ["task_definition_id"], name: "index_communication_actions_on_task_definition_id"
    t.index ["type"], name: "index_communication_actions_on_type"
  end

  create_table "communication_conditions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "type", null: false
    t.bigint "communication_id", null: false
    t.integer "target_grade"
    t.bigint "task_definition_id"
    t.text "task_statuses", size: :long, collation: "utf8mb4_bin"
    t.datetime "last_sign_in_at"
    t.bigint "tutorial_id"
    t.bigint "tutorial_stream_id"
    t.bigint "campus_id"
    t.integer "task_status_count"
    t.integer "task_target_grade"
    t.integer "spec_con_days"
    t.string "operator", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campus_id"], name: "index_communication_conditions_on_campus_id"
    t.index ["communication_id"], name: "index_communication_conditions_on_communication_id"
    t.index ["task_definition_id"], name: "index_communication_conditions_on_task_definition_id"
    t.index ["tutorial_id"], name: "index_communication_conditions_on_tutorial_id"
    t.index ["tutorial_stream_id"], name: "index_communication_conditions_on_tutorial_stream_id"
    t.index ["type"], name: "index_communication_conditions_on_type"
    t.check_constraint "json_valid(`task_statuses`)", name: "task_statuses"
  end

  create_table "communication_rules", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "communication_set_id", null: false
    t.integer "position", default: 0, null: false
    t.string "name"
    t.string "operator"
    t.boolean "send_log_to_convenors", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["communication_set_id"], name: "index_communication_rules_on_communication_set_id"
  end

  create_table "communication_set_schedules", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "communication_set_id", null: false
    t.string "name"
    t.boolean "active", default: true, null: false
    t.integer "anchor_week", null: false
    t.string "anchor_day", null: false
    t.integer "hour", default: 8, null: false
    t.integer "minute", default: 0, null: false
    t.string "timezone", default: "UTC", null: false
    t.string "recurrence", default: "none", null: false
    t.integer "interval", default: 1, null: false
    t.integer "repeat_count"
    t.datetime "until_at"
    t.text "ice_cube_schedule", size: :long, collation: "utf8mb4_bin"
    t.datetime "next_run_at"
    t.datetime "last_run_at"
    t.datetime "last_enqueued_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "next_run_at"], name: "index_communication_set_schedules_on_active_and_next_run_at"
    t.index ["communication_set_id"], name: "index_communication_set_schedules_on_communication_set_id"
    t.check_constraint "json_valid(`ice_cube_schedule`)", name: "ice_cube_schedule"
  end

  create_table "communication_sets", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "unit_id", null: false
    t.string "name"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id"], name: "index_communication_sets_on_unit_id"
  end

  create_table "d2l_assessment_mappings", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "unit_id", null: false
    t.string "org_unit_id"
    t.integer "grade_object_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id"], name: "index_d2l_assessment_mappings_on_unit_id", unique: true
  end

  create_table "discussion_comments", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "time_started"
    t.datetime "time_completed"
    t.integer "number_of_prompts"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "discussion_prompts", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_definition_id", null: false
    t.text "content", null: false
    t.integer "priority", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_definition_id"], name: "index_discussion_prompts_on_task_definition_id"
  end

  create_table "engagement_comments", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "engagement_id", null: false
    t.bigint "user_id", null: false
    t.bigint "reply_to_id"
    t.text "comment", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["engagement_id"], name: "index_engagement_comments_on_engagement_id"
    t.index ["reply_to_id"], name: "index_engagement_comments_on_reply_to_id"
    t.index ["user_id"], name: "index_engagement_comments_on_user_id"
  end

  create_table "engagements", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.string "engagement_type", null: false
    t.text "note", null: false
    t.datetime "occurred_at", null: false
    t.text "evidence_url"
    t.string "content_type"
    t.string "attachment_extension"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "occurred_at"], name: "index_engagements_on_project_id_and_occurred_at"
    t.index ["project_id"], name: "index_engagements_on_project_id"
    t.index ["user_id"], name: "index_engagements_on_user_id"
  end

  create_table "feedback_chips", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "type"
    t.text "chip_text"
    t.text "description"
    t.text "comment_text"
    t.text "summary_text"
    t.bigint "learning_outcome_id", null: false
    t.bigint "parent_chip_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "task_status"
    t.index ["learning_outcome_id"], name: "index_feedback_chips_on_learning_outcome_id"
    t.index ["parent_chip_id"], name: "index_feedback_chips_on_parent_chip_id"
  end

  create_table "group_memberships", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "group_id"
    t.bigint "project_id"
    t.boolean "active", default: true
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["project_id"], name: "index_group_memberships_on_project_id"
  end

  create_table "group_sets", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "unit_id"
    t.string "name"
    t.boolean "allow_students_to_create_groups", default: true
    t.boolean "allow_students_to_manage_groups", default: true
    t.boolean "keep_groups_in_same_class", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "capacity"
    t.boolean "locked", default: false, null: false
    t.index ["name", "unit_id"], name: "index_group_sets_on_name_and_unit_id", unique: true
    t.index ["unit_id"], name: "index_group_sets_on_unit_id"
  end

  create_table "group_submissions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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

  create_table "groups", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "group_set_id"
    t.bigint "tutorial_id"
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "capacity_adjustment", default: 0, null: false
    t.boolean "locked", default: false, null: false
    t.index ["group_set_id"], name: "index_groups_on_group_set_id"
    t.index ["name", "group_set_id"], name: "index_groups_on_name_and_group_set_id", unique: true
    t.index ["tutorial_id"], name: "index_groups_on_tutorial_id"
  end

  create_table "learning_outcome_links", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "source_id", null: false
    t.bigint "target_id", null: false
    t.string "link_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id", "target_id"], name: "index_learning_outcome_links_on_source_id_and_target_id", unique: true
    t.index ["source_id"], name: "index_learning_outcome_links_on_source_id"
    t.index ["target_id"], name: "index_learning_outcome_links_on_target_id"
  end

  create_table "learning_outcomes", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "short_description"
    t.string "full_outcome_description", limit: 4096
    t.string "abbreviation"
    t.bigint "context_id"
    t.string "context_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["abbreviation", "context_type", "context_id"], name: "index_learning_outcomes_on_abbreviation_and_context", unique: true
    t.index ["context_id", "context_type"], name: "index_learning_outcomes_on_context_id_and_context_type"
  end

  create_table "logins", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "timestamp"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_logins_on_user_id"
  end

  create_table "marking_sessions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "unit_id", null: false
    t.string "ip_address"
    t.datetime "start_time"
    t.datetime "end_time"
    t.boolean "during_tutorial"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id"], name: "index_marking_sessions_on_unit_id"
    t.index ["user_id", "unit_id", "ip_address", "updated_at"], name: "index_marking_sessions_on_user_unit_ip_and_time"
    t.index ["user_id"], name: "index_marking_sessions_on_user_id"
  end

  create_table "moderated_tasks", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "task_definition_id", null: false
    t.datetime "last_moderated_date"
    t.string "state", null: false
    t.string "moderation_type", null: false
    t.bigint "assessor_id"
    t.bigint "resolved_by_user_id"
    t.datetime "resolved_at"
    t.string "outcome"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assessor_id", "task_definition_id", "moderation_type"], name: "idx_mod_tasks_assessor_td_type"
    t.index ["task_definition_id"], name: "index_moderated_tasks_on_task_definition_id"
    t.index ["task_id", "moderation_type"], name: "uniq_mod_tasks_task_type", unique: true
    t.index ["task_id"], name: "index_moderated_tasks_on_task_id"
  end

  create_table "overflow_task_claim_logs", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "unit_id", null: false
    t.bigint "task_id", null: false
    t.bigint "claimed_by_unit_role_id", null: false
    t.bigint "claimed_by_user_id", null: false
    t.bigint "original_tutor_user_id"
    t.bigint "student_user_id", null: false
    t.integer "days_awaiting_feedback", null: false
    t.datetime "claimed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claimed_by_unit_role_id"], name: "index_overflow_task_claim_logs_on_claimed_by_unit_role_id"
    t.index ["claimed_by_user_id"], name: "index_overflow_task_claim_logs_on_claimed_by_user_id"
    t.index ["original_tutor_user_id"], name: "index_overflow_task_claim_logs_on_original_tutor_user_id"
    t.index ["student_user_id"], name: "index_overflow_task_claim_logs_on_student_user_id"
    t.index ["task_id"], name: "index_overflow_task_claim_logs_on_task_id"
    t.index ["unit_id", "claimed_at"], name: "index_overflow_task_claim_logs_on_unit_id_and_claimed_at"
    t.index ["unit_id"], name: "index_overflow_task_claim_logs_on_unit_id"
  end

  create_table "overflow_task_claims", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "claimed_by_unit_role_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_overflow_task_claims_on_task_id", unique: true
  end

  create_table "overseer_assessments", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "submission_timestamp", null: false
    t.string "result_task_status"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "total_steps"
    t.datetime "student_notified_at"
    t.bigint "submission_history_id", null: false
    t.index ["status", "student_notified_at", "updated_at"], name: "index_overseer_assessments_on_status_notified_updated"
    t.index ["submission_history_id"], name: "index_overseer_assessments_on_submission_history_id", unique: true
    t.index ["task_id", "submission_timestamp"], name: "index_overseer_assessments_on_task_id_and_submission_timestamp", unique: true
    t.index ["task_id"], name: "index_overseer_assessments_on_task_id"
  end

  create_table "overseer_images", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "tag", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "pulled_image_text"
    t.integer "pulled_image_status"
    t.datetime "last_pulled_date"
    t.index ["name"], name: "index_overseer_images_on_name", unique: true
    t.index ["tag"], name: "index_overseer_images_on_tag", unique: true
  end

  create_table "overseer_step_results", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "overseer_assessment_id", null: false
    t.bigint "overseer_step_id", null: false
    t.integer "exit_status", default: -1, null: false
    t.boolean "pass", default: false, null: false
    t.text "feedback_message"
    t.text "stdout"
    t.text "stdin"
    t.text "expected_output"
    t.string "stdout_sha256"
    t.string "stdin_sha256"
    t.string "expected_output_sha256"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["overseer_assessment_id"], name: "index_overseer_step_results_on_overseer_assessment_id"
    t.index ["overseer_step_id"], name: "index_overseer_step_results_on_overseer_step_id"
  end

  create_table "overseer_steps", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_definition_id", null: false
    t.string "name", null: false
    t.text "description"
    t.string "display_name", null: false
    t.string "display_description"
    t.text "run_command"
    t.integer "timeout", default: 30, null: false
    t.integer "sort_order", default: 0, null: false
    t.string "step_type", null: false
    t.boolean "partial_output_diff"
    t.string "stdin_input_file"
    t.string "expected_output_file"
    t.text "feedback_message"
    t.bigint "status_on_success_id"
    t.bigint "status_on_failure_id"
    t.boolean "halt_on_success"
    t.boolean "halt_on_failure"
    t.boolean "show_expected_output"
    t.boolean "show_stdin"
    t.boolean "show_stdout"
    t.boolean "enabled", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status_on_failure_id"], name: "index_overseer_steps_on_status_on_failure_id"
    t.index ["status_on_success_id"], name: "index_overseer_steps_on_status_on_success_id"
    t.index ["task_definition_id"], name: "index_overseer_steps_on_task_definition_id"
  end

  create_table "projects", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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
    t.integer "spec_con_days", default: 0, null: false
    t.bigint "assessor_id"
    t.datetime "portfolio_submission_date"
    t.index ["assessor_id"], name: "index_projects_on_assessor_id"
    t.index ["campus_id"], name: "index_projects_on_campus_id"
    t.index ["enrolled"], name: "index_projects_on_enrolled"
    t.index ["unit_id", "user_id"], name: "index_projects_on_unit_id_and_user_id", unique: true
    t.index ["unit_id"], name: "index_projects_on_unit_id"
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "roles", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "session_activities", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "marking_session_id", null: false
    t.string "action"
    t.bigint "project_id"
    t.bigint "task_id"
    t.bigint "task_definition_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action", "task_id", "created_at"], name: "index_session_activities_on_action_task_created_at"
    t.index ["marking_session_id"], name: "index_session_activities_on_marking_session_id"
    t.index ["project_id"], name: "index_session_activities_on_project_id"
    t.index ["task_definition_id"], name: "index_session_activities_on_task_definition_id"
    t.index ["task_id"], name: "index_session_activities_on_task_id"
  end

  create_table "staff_notes", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.text "note"
    t.bigint "project_id", null: false
    t.bigint "user_id", null: false
    t.bigint "staff_notes_id"
    t.bigint "reply_to_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_staff_notes_on_project_id"
    t.index ["reply_to_id"], name: "index_staff_notes_on_reply_to_id"
    t.index ["staff_notes_id"], name: "index_staff_notes_on_staff_notes_id"
    t.index ["user_id"], name: "index_staff_notes_on_user_id"
  end

  create_table "submission_histories", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "submission_timestamp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id", "submission_timestamp"], name: "index_submission_histories_on_task_and_timestamp", unique: true
    t.index ["task_id"], name: "index_submission_histories_on_task_id"
  end

  create_table "task_comments", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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
    t.bigint "commentable_id"
    t.string "commentable_type"
    t.index ["assessor_id"], name: "index_task_comments_on_assessor_id"
    t.index ["commentable_type", "commentable_id"], name: "index_task_comments_on_commentable_type_and_commentable_id"
    t.index ["discussion_comment_id"], name: "index_task_comments_on_discussion_comment_id"
    t.index ["recipient_id"], name: "fk_rails_1dbb49165b"
    t.index ["reply_to_id"], name: "index_task_comments_on_reply_to_id"
    t.index ["task_id"], name: "index_task_comments_on_task_id"
    t.index ["task_status_id"], name: "index_task_comments_on_task_status_id"
    t.index ["user_id"], name: "index_task_comments_on_user_id"
  end

  create_table "task_completion_snapshots", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "unit_id", null: false
    t.string "snapshot_timestamp", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id", "snapshot_timestamp"], name: "idx_on_unit_id_snapshot_timestamp_e923c3ae10", unique: true
    t.index ["unit_id"], name: "index_task_completion_snapshots_on_unit_id"
  end

  create_table "task_definition_grade_due_dates", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_definition_id", null: false
    t.integer "target_grade", null: false
    t.datetime "target_due_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "start_date"
    t.index ["task_definition_id", "target_grade"], name: "idx_td_grade_due_unique", unique: true
    t.index ["task_definition_id"], name: "index_task_definition_grade_due_dates_on_task_definition_id"
  end

  create_table "task_definitions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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
    t.string "similarity_language"
    t.boolean "scorm_enabled", default: false
    t.boolean "scorm_allow_review", default: false
    t.boolean "scorm_bypass_test", default: false
    t.boolean "scorm_time_delay_enabled", default: false
    t.integer "scorm_attempt_limit", default: 0
    t.boolean "assess_in_portfolio_only", default: false, null: false
    t.boolean "use_resources_for_jplag_base_code", default: false, null: false
    t.boolean "lock_assessments_to_tutorial_stream", default: false, null: false
    t.boolean "requires_discussion", default: false, null: false
    t.index ["abbreviation", "unit_id"], name: "index_task_definitions_on_abbreviation_and_unit_id", unique: true
    t.index ["group_set_id"], name: "index_task_definitions_on_group_set_id"
    t.index ["name", "unit_id"], name: "index_task_definitions_on_name_and_unit_id", unique: true
    t.index ["overseer_image_id"], name: "index_task_definitions_on_overseer_image_id"
    t.index ["tutorial_stream_id"], name: "index_task_definitions_on_tutorial_stream_id"
    t.index ["unit_id"], name: "index_task_definitions_on_unit_id"
  end

  create_table "task_engagements", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "engagement_time"
    t.string "engagement"
    t.bigint "task_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id"], name: "index_task_engagements_on_task_id"
  end

  create_table "task_pins", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id", "user_id"], name: "index_task_pins_on_task_id_and_user_id", unique: true
    t.index ["task_id"], name: "index_task_pins_on_task_id"
    t.index ["user_id"], name: "fk_rails_915df186ed"
  end

  create_table "task_prerequisites", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_definition_id", null: false
    t.bigint "prerequisite_id", null: false
    t.bigint "task_status_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["prerequisite_id"], name: "index_task_prerequisites_on_prerequisite_id"
    t.index ["task_definition_id", "prerequisite_id"], name: "idx_on_task_definition_id_prerequisite_id_90b47ca126", unique: true
    t.index ["task_definition_id"], name: "index_task_prerequisites_on_task_definition_id"
    t.index ["task_status_id"], name: "index_task_prerequisites_on_task_status_id"
  end

  create_table "task_similarities", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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

  create_table "task_statuses", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "task_submissions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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

  create_table "tasks", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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
    t.datetime "target_start_date"
    t.datetime "target_due_date"
    t.datetime "last_tutor_feedback_at"
    t.index ["group_submission_id"], name: "index_tasks_on_group_submission_id"
    t.index ["project_id", "task_definition_id"], name: "tasks_uniq_proj_task_def", unique: true
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["task_definition_id"], name: "index_tasks_on_task_definition_id"
    t.index ["task_status_id"], name: "index_tasks_on_task_status_id"
  end

  create_table "teaching_periods", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "period", null: false
    t.datetime "start_date", null: false
    t.datetime "end_date", null: false
    t.integer "year", null: false
    t.datetime "active_until", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["period", "year"], name: "index_teaching_periods_on_period_and_year", unique: true
  end

  create_table "test_attempts", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "task_id"
    t.datetime "attempted_time", null: false
    t.boolean "terminated", default: false
    t.boolean "completion_status", default: false
    t.boolean "success_status", default: false
    t.float "score_scaled", default: 0.0
    t.text "cmi_datamodel"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "tutor_feedback_scores", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "unit_role_id", null: false
    t.bigint "task_definition_id", null: false
    t.integer "score", default: 50, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_definition_id"], name: "index_tutor_feedback_scores_on_task_definition_id"
    t.index ["unit_role_id"], name: "index_tutor_feedback_scores_on_unit_role_id"
  end

  create_table "tutor_notes", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.text "note"
    t.bigint "task_id"
    t.bigint "unit_role_id", null: false
    t.bigint "user_id", null: false
    t.bigint "reply_to_id"
    t.boolean "read_by_unit_role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reply_to_id"], name: "index_tutor_notes_on_reply_to_id"
    t.index ["task_id"], name: "index_tutor_notes_on_task_id"
    t.index ["unit_role_id"], name: "index_tutor_notes_on_unit_role_id"
    t.index ["user_id"], name: "index_tutor_notes_on_user_id"
  end

  create_table "tutorial_enrolments", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "project_id", null: false
    t.bigint "tutorial_id", null: false
    t.index ["project_id"], name: "index_tutorial_enrolments_on_project_id"
    t.index ["tutorial_id", "project_id"], name: "index_tutorial_enrolments_on_tutorial_id_and_project_id", unique: true
    t.index ["tutorial_id"], name: "index_tutorial_enrolments_on_tutorial_id"
  end

  create_table "tutorial_streams", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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

  create_table "tutorials", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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
    t.index ["abbreviation", "unit_id"], name: "index_tutorials_on_abbreviation_and_unit_id", unique: true
    t.index ["campus_id"], name: "index_tutorials_on_campus_id"
    t.index ["tutorial_stream_id"], name: "index_tutorials_on_tutorial_stream_id"
    t.index ["unit_id"], name: "index_tutorials_on_unit_id"
    t.index ["unit_role_id"], name: "index_tutorials_on_unit_role_id"
  end

  create_table "unit_roles", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "tutorial_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "role_id"
    t.bigint "unit_id"
    t.boolean "observer_only", default: false
    t.bigint "mentor_id"
    t.boolean "can_mark_overflow_tasks", default: false
    t.index ["mentor_id"], name: "index_unit_roles_on_mentor_id"
    t.index ["role_id"], name: "index_unit_roles_on_role_id"
    t.index ["tutorial_id"], name: "index_unit_roles_on_tutorial_id"
    t.index ["unit_id"], name: "index_unit_roles_on_unit_id"
    t.index ["user_id"], name: "index_unit_roles_on_user_id"
  end

  create_table "units", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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
    t.boolean "archived", default: false
    t.boolean "allow_flexible_dates", default: false, null: false
    t.datetime "portfolio_due_date"
    t.boolean "mark_late_submissions_as_assess_in_portfolio", default: false, null: false
    t.integer "feedback_warning_threshold_days", default: 5
    t.integer "feedback_overflow_threshold_days", default: 7
    t.boolean "enforce_feedback_before_discussed_in_class", default: false, null: false
    t.text "grade_values", size: :long, collation: "utf8mb4_bin"
    t.index ["draft_task_definition_id"], name: "index_units_on_draft_task_definition_id"
    t.index ["main_convenor_id"], name: "index_units_on_main_convenor_id"
    t.index ["overseer_image_id"], name: "index_units_on_overseer_image_id"
    t.index ["teaching_period_id"], name: "index_units_on_teaching_period_id"
    t.check_constraint "json_valid(`grade_values`)", name: "grade_values"
  end

  create_table "user_oauth_states", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "state"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["state"], name: "index_user_oauth_states_on_state", unique: true
    t.index ["user_id"], name: "index_user_oauth_states_on_user_id"
  end

  create_table "user_oauth_tokens", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "provider", default: 0, null: false
    t.text "token"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_oauth_tokens_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["login_id"], name: "index_users_on_login_id", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["student_id"], name: "index_users_on_student_id", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "webcal_unit_exclusions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "webcal_id", null: false
    t.bigint "unit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id", "webcal_id"], name: "index_webcal_unit_exclusions_on_unit_id_and_webcal_id", unique: true
    t.index ["unit_id"], name: "index_webcal_unit_exclusions_on_unit_id"
    t.index ["webcal_id"], name: "fk_rails_d5fab02cb7"
  end

  create_table "webcals", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "guid", limit: 36, null: false
    t.boolean "include_start_dates", default: false, null: false
    t.bigint "user_id"
    t.integer "reminder_time"
    t.string "reminder_unit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guid"], name: "index_webcals_on_guid", unique: true
    t.index ["user_id"], name: "index_webcals_on_user_id", unique: true
  end

  add_foreign_key "chip_usages", "feedback_chips"
  add_foreign_key "chip_usages", "users", column: "tutor_id"
  add_foreign_key "feedback_chips", "feedback_chips", column: "parent_chip_id"
  add_foreign_key "feedback_chips", "learning_outcomes"
  add_foreign_key "learning_outcome_links", "learning_outcomes", column: "source_id"
  add_foreign_key "learning_outcome_links", "learning_outcomes", column: "target_id"
  add_foreign_key "user_oauth_states", "users"
  add_foreign_key "user_oauth_tokens", "users"
end
