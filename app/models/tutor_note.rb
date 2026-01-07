class TutorNote < ApplicationRecord
  belongs_to :unit_role
  belongs_to :user
  belongs_to :reply_to, class_name: "TutorNote", optional: true
end
