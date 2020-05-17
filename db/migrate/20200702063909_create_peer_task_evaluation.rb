class CreatePeerTaskEvaluation < ActiveRecord::Migration
	def change
    create_table :task_peer_evaluations do |t|
     	t.references :task_evaluation_question
     	t.references :project
     	t.integer    :evaluation,                null: false
     	t.timestamps   
    end
  end 
end