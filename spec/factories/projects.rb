FactoryBot.define do
  factory :project do
    association :user
    sequence(:title) { |n| "Project #{n}" }
    transient do
      scores_count { 0 }
    end
    after(:create) do |project, evaluator|
      create_list(:score, evaluator.scores_count, project: project) if evaluator.scores_count.positive?
    end
  end
end
