class CreateGroupMemberEvaluations < ActiveRecord::Migration
	def change
    create_table :group_member_evaluations do |t|
     	t.references :group_membership
     	t.references :project
     	t.float      :evaluation,                null: false
     	t.timestamps   
    end
  end 
end