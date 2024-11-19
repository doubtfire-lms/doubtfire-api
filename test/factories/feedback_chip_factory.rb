FactoryBot.define do
  factory :feedback_group_chip do
    title { "Sample title" }
    parent_chip_id { nil }
    child_chip_id { nil }
    belongs_to { "Sample belongs to" }
    belongs_to_tlo { "Sample belongs to TLO" }
  end

  factory :feedback_template_chip do
    abbreviation { "Sample abbreviation" }
    order { 1 }
    chip_text { "Sample chip text" }
    description { "Sample description" }
    comment_text { "Sample comment text" }
    summary_text { "Sample summary text" }
    task_status { "In Progress" }
  end
end
