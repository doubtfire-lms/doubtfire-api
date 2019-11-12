class AddTutorialStreamToTaskDefinition < ActiveRecord::Migration
  def change
    add_reference :task_definitions, :tutorial_stream, foreign_key: true, index: true
  end
end
