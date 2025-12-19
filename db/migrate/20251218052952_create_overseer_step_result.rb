class CreateOverseerStepResult < ActiveRecord::Migration[8.0]
  def change
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
  end
end
