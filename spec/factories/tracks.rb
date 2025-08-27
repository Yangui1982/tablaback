FactoryBot.define do
  factory :track do
    association :score
    sequence(:name) { |n| "Track #{n}" }
    instrument { "Electric Guitar" }
    tuning     { "EADGBE" }
    capo       { 0 }
    midi_channel { nil }

    trait :with_midi_channel do
      midi_channel { 1 }
    end
  end
end
