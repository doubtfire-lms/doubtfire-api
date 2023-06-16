
FactoryBot.define do
    factory :feedback_comment do
        
        association :feedback_comment_template
        association :criterion_option
    end
end
