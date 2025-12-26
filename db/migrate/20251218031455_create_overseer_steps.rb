class CreateOverseerSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :overseer_steps do |t|
      t.references :task_definition, null: false

      # Staff only
      t.string  :name, null: false
      t.text    :description

      # Shown to the student
      t.string :display_name, null: false
      t.string :display_description

      t.text    :run_command

      t.integer :timeout, default: 30, null: false
      t.integer :sort_order, default: 0, null: false

      t.string  :step_type, null: false # "status_check", "output_diff", etc.
      t.boolean :partial_output_diff

      t.string :stdin_input_file # Name of file (or path) in assessment resources
      t.string :expected_output_file # Name of file in (or path) assessment resources

      t.text :feedback_message

      t.references :status_on_success
      t.references :status_on_failure

      t.boolean :halt_on_success
      t.boolean :halt_on_failure

      t.boolean :show_expected_output
      t.boolean :show_stdin
      t.boolean :show_stdout

      t.boolean :enabled, default: true

      t.timestamps
    end

    create_table :overseer_step_results do |t|
      t.references :overseer_assessment, null: false
      t.references :overseer_step, null: false

      t.integer :exit_status, null: false, default: -1
      t.boolean :pass, null: false, default: false

      t.text :feedback_message

      # The output from the overseer script and student's submission
      t.text :stdout

      # The original input/output files, in case they have since been changed
      t.text :stdin
      t.text :expected_output

      # We may want to discard the original_stdin, expected_output, and stdout when archiving a unit.
      # Storing hashes will allow us to confirm if the original outputs matched
      t.string :stdout_sha256
      t.string :stdin_sha256
      t.string :expected_output_sha256

      t.timestamps
    end

    # Track the number of available steps at the time of assessment
    add_column :overseer_assessments, :total_steps, :integer
  end
end
