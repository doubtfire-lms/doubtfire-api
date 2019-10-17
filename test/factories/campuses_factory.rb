FactoryGirl.define do
  factory :campus do
    campus_name         = ['Melbourne', 'Sydney', 'Perth', 'Hobart'].sample
    campus_abbreviation = campus_name[0...3]

    name          campus_name
    abbreviation  campus_abbreviation
    mode          { ['timetable', 'automatic', 'manual'].sample }
  end
end