class PlagiarismMatchLink < ActiveRecord::Base
	belongs_to :task
	belongs_to :other_task, :class_name => 'Task'

	before_destroy do | match_link |
		begin
			FileHelper.delete_plagarism_html(match_link)
		rescue
		end
	end
end