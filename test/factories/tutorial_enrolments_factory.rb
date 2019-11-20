FactoryGirl.define do
  factory :tutorial_enrolment do
    project

    after(:build) do |tutorial_enrolment|
      tutorial_enrolment.tutorial = FactoryGirl.create(:tutorial, unit: tutorial_enrolment.project.unit, campus: tutorial_enrolment.project.campus)
    end
  end
end
