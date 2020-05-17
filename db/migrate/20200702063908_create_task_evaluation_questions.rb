class CreateTaskEvaluationQuestions < ActiveRecord::Migration
	def change
    create_table :task_evaluation_questions do |t|
     	t.references :peer_task_evaluation_question
     	t.references :task_definition
     	t.timestamps   
    end
  end 
end