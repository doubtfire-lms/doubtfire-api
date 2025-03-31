FactoryBot.define do
  factory :course, class: 'Courseflow::Course' do
    name { "Bachelor of Computer Science" }
    code { "S306" }
    year { 2024 }
    version { "1.0" }
    url { "https://www.deakin.edu.au/current-students-courses/course.php?course=S306&version=2&year=2024&keywords=computer+science" }
  end
end
