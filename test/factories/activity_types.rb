FactoryGirl.define do
  factory :activity_type do
    name          { Populator.words(1..2) }
    abbreviation  { Populator.words(1) }
  end
end
