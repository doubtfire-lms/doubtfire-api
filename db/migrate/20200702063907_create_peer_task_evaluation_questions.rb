class CreatePeerTaskEvaluationQuestions < ActiveRecord::Migration
	def change
    create_table :peer_task_evaluation_questions do |t|
      t.text            :description, null: false  
      t.timestamps   
    end
  end 
end