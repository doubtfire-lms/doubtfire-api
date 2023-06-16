FactoryBot.define do
    factory :feedback_comment_template do
      criterion_option
  
      comment_text_situation    { Faker::Lorem.sentence }
      comment_text_next_action  { Faker::Lorem.sentence }
    end
end
