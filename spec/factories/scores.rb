FactoryBot.define do
  factory :score do
    association :project
    sequence(:title) { |n| "Score #{n}" }
    status { :draft }
    doc do
      {
        schema_version: 1,
        title: "Score",
        tempo: { bpm: 120, map: [] },
        tracks: [],
        measures: []
      }
    end
    tempo { nil }

    trait :with_tracks do
      transient do
        tracks_count { 1 }
      end

      after(:create) do |score, evaluator|
        create_list(:track, evaluator.tracks_count, score: score)
      end
    end

    trait :ready do
      status { :ready }
    end

    trait :with_source_file do
      after(:create) do |score|
        file = Rails.root.join("spec/fixtures/files/sample.musicxml")
        if File.exist?(file)
          score.source_file.attach(
            io: File.open(file),
            filename: "sample.musicxml",
            content_type: "application/xml"
          )
        end
      end
    end
  end
end
