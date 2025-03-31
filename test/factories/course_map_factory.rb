FactoryBot.define do
  factory :course_map, class: 'Courseflow::CourseMap' do
    userId { 1 }
    courseId { 1 }
  end
end
