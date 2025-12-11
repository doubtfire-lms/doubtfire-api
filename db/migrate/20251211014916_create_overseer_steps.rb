class CreateOverseerSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :overseer_steps do |t|
      t.references :task_definition

      t.string  :name, null: false
      t.text    :description
      # t.text    :script, null: false # This will belong to a file path
      # t.string  :interpreter, default: "bash"
      t.integer :timeout_ms, default: 1000
      t.integer :sort_order, default: 0

      t.string  :step_type, null: false      # "status_check", "output_diff", etc.
      t.string  :visibility, null: false     # "public", "masked", "hidden"
      # public => Student can see the name/desc, input & output logs and feedback message. Sees if it was a pass or fail
      # masked => Student can see the name/desc, not the input/output. Sees if it was a pass or fail
      # hidden => Student doesn't know this step exists, has no effect on the task status

      # TODO: maybe these could be a dropdown of the assessment resources we have, so that when we load our TaskDefinition details we should a list of all file paths
      t.string :stdin_input_file # Name of file (or path) in assessment resources
      t.string :expected_output_file # Name of file in (or path) assessment resources

      t.text :feedback_message # Only shown on fail

      t.references :status_on_success
      t.references :status_on_failed

      t.boolean :enabled, default: true

      t.timestamps
    end
  end
end
