FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "secret1234" }
    trait :confirmed do
      after(:build) do |user|
        if user.respond_to?(:confirmed_at) && user.has_attribute?(:confirmed_at)
          user.confirmed_at ||= Time.current
        end
      end
    end
  end
end
