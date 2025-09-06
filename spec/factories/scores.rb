# spec/factories/scores.rb
FactoryBot.define do
  factory :score do
    association :project
    sequence(:title) { |n| "Score #{n}" }
    status { :draft }
    imported_format { nil }   # laisse l'inférence décider si besoin
    tempo { nil }

    # Doc conforme aux lecteurs du modèle (tempo_bpm)
    doc do
      {
        "schema_version" => 1,
        "title"          => "Score",
        "tempo_bpm"      => 120,
        "tracks"         => [],
        "measures"       => []
      }
    end

    # ----------------- États -----------------
    trait :processing do
      status { :processing }
    end

    trait :ready do
      status { :ready }
    end

    trait :failed do
      status { :failed }
    end

    # -------------- Formats (enum) -----------
    trait :fmt_mxl do
      imported_format { "mxl" }
    end

    trait :fmt_musicxml do
      imported_format { "musicxml" }
    end

    trait :fmt_guitarpro do
      imported_format { "guitarpro" }
    end

    # --------- Fichiers source (fixtures) ----
    # Attache un MusicXML "clair"
    trait :with_source_xml do
      after(:create) do |score|
        path = Rails.root.join("spec/fixtures/files/sample.musicxml")
        io   = File.exist?(path) ? File.open(path, "rb") : StringIO.new("<score-partwise version=\"3.1\"></score-partwise>")
        blob = ActiveStorage::Blob.create_and_upload!(
          io: io,
          filename: "sample.musicxml",
          content_type: "application/xml"
        )
        ActiveStorage::Attachment.create!(name: "source_file", record: score, blob: blob)
        # fixe explicitement le format pour éviter la variabilité des tests
        score.update_column(:imported_format, "musicxml") if score.imported_format.nil?
      end
    end

    # Attache un MXL (canon)
    trait :with_source_mxl do
      after(:create) do |score|
        path = Rails.root.join("spec/fixtures/files/sample.mxl")
        io =
          if File.exist?(path)
            File.open(path, "rb")
          else
            # zip minimal (signature PK) pour un blob valide en test
            StringIO.new("PK\x03\x04")
          end
        blob = ActiveStorage::Blob.create_and_upload!(
          io: io,
          filename: "sample.mxl",
          content_type: "application/vnd.recordare.musicxml"
        )
        ActiveStorage::Attachment.create!(name: "source_file", record: score, blob: blob)
        score.update_column(:imported_format, "mxl") if score.imported_format.nil?
      end
    end

    # Attache un fichier Guitar Pro (ex: .gp3)
    trait :with_source_gp do
      after(:create) do |score|
        path = Rails.root.join("spec/fixtures/files/sample.gp3")
        io   = File.exist?(path) ? File.open(path, "rb") : StringIO.new("GP3DUMMY")
        blob = ActiveStorage::Blob.create_and_upload!(
          io: io,
          filename: "sample.gp3",
          content_type: "application/octet-stream"
        )
        ActiveStorage::Attachment.create!(name: "source_file", record: score, blob: blob)
        score.update_column(:imported_format, "guitarpro") if score.imported_format.nil?
      end
    end

    # Cas volontairement non supporté (extension inconnue) pour tests de robustesse
    trait :with_source_unsupported do
      after(:create) do |score|
        path = Rails.root.join("spec/fixtures/files/dummy.txt")
        io   = File.exist?(path) ? File.open(path, "rb") : StringIO.new("bogus")
        blob = ActiveStorage::Blob.create_and_upload!(
          io: io,
          filename: "dummy.txt",                   # extension inconnue -> infer 'unknown'
          content_type: "application/octet-stream" # autorisé par ALLOWED_SOURCE_TYPES
        )
        ActiveStorage::Attachment.create!(name: "source_file", record: score, blob: blob)
        # important: laisser nil pour forcer l'inférence par le nom de fichier dans le job
        score.update_column(:imported_format, nil)
      end
    end

    # ---------- Tracks associés -------------
    trait :with_tracks do
      transient do
        tracks_count { 1 }
      end

      after(:create) do |score, evaluator|
        create_list(:track, evaluator.tracks_count, score: score)
      end
    end
  end
end
