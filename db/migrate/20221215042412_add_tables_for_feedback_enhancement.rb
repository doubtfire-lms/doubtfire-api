class AddTablesForFeedbackEnhancement < ActiveRecord::Migration[7.0]
  def change
    create_table :stages do |t|
      # Fields
      t.integer    :order, null: false
      t.string     :title, null: false
      t.string     :help_text
      t.string     :entry_message
      t.string     :exit_message_good
      t.string     :exit_message_resubmit

      # Foreign keys
      t.references :task_definition
    end

    create_table :criteria do |t| # "criteria" is set as plural of "criterion" in 'doubtfire-api/config/initializers/inflections.rb'
      # Fields
      t.integer     :order, null: false
      t.string      :description, null: false
      t.string      :help_text

      # Foreign keys
      t.references  :stage
    end

    create_table :criterion_options do |t|
      # Fields
      t.string      :resolved_message_text
      t.string      :unresolved_message_text

      # Foreign keys
      t.references  :criterion
      t.references  :task_status # i.e. "complete", "fail", "fix_and_resubmit", etc
    end

    create_table :feedback_comment_templates do |t|
      # Fields
      t.string      :comment_text_situation, null: false
      t.string      :comment_text_next_action

      #Foreign keys
      t.references  :criterion_option
      t.references  :user
    end

    add_reference :task_comments, :feedback_comment_template, index: true
    add_reference :task_comments, :criterion_option, index: true
  end
end
