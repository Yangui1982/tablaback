FactoryBot.define do
  sequence :midi_channel_seq do |n|
    ((n - 1) % 16) + 1
  end

  factory :track do
    association :score

    sequence(:name) { |n| "Track #{n}" }
    instrument { "Electric Guitar" }
    tuning     { "E A D G B E" }
    capo       { 0 }
    midi_channel { nil }

    trait :with_midi_channel do
      transient do
        channel { 1 }
      end
      midi_channel { channel }
    end

    trait :random_channel do
      midi_channel { (1..16).to_a.sample }
    end

    trait :unique_midi_channel do
      midi_channel { generate(:midi_channel_seq) }
    end

    trait :channel_1 do
      midi_channel { 1 }
    end

    trait :channel_10 do
      midi_channel { 10 }
    end

    trait :duplicate_name do
      name { "Duplicate" }
    end

    trait :bass do
      instrument { "Bass" }
      tuning     { "E A D G" }
    end

    trait :seven_string do
      instrument { "7-String Guitar" }
      tuning     { "B E A D G B E" }
    end
  end
end
