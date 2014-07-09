class Role < ActiveRecord::Base
	ADMIN = 'admin'
	CONVENOR = 'convenor'
	TUTOR = 'tutor'
	STUDENT = 'student'

	ROLES = [ADMIN, CONVENOR, TUTOR, STUDENT]


	scope :student, 	-> { Role.find(1) }
	scope :tutor, 		-> { Role.find(2) }
	scope :convenor,	-> { Role.find(3) }
	scope :moderator, 	-> { Role.find(4) }

	#
	# Helpers to get the role id's:
	# - These could be made into DB queries, but these values should not change
	#
	def self.tutor_id
		2
	end

	def self.convenor_id
		3
	end

	def self.student_id
		1
	end

	def self.moderator_id
		4
	end
end