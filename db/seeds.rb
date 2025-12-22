# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# db/seeds.rb

abort("Refus d'exécuter les seeds en production") if Rails.env.production?
puts "==> Seeding (env: #{Rails.env})"

# -- Helpers -----------------------------------------------------------------
def reset_pk_sequences!(table_names)
  return unless ActiveRecord::Base.connection.respond_to?(:reset_pk_sequence!)
  table_names.each do |t|
    next unless ActiveRecord::Base.connection.data_source_exists?(t)
    ActiveRecord::Base.connection.reset_pk_sequence!(t)
  end
end

def table_exists?(name)
  ActiveRecord::Base.connection.data_source_exists?(name)
end

# -- Cleanup -----------------------------------------------------------------
FULL_WIPE  = ENV["FULL_WIPE"] == "1"
TEST_EMAIL = "test@exemple.com"

puts "==> Cleanup..."
if FULL_WIPE
  puts " FULL_WIPE=1 -> suppression TOTALE des données…"

  # détruire d'abord les enfants
  Object.const_defined?("Track")  && Track.delete_all
  Object.const_defined?("Score")  && Score.delete_all
  Object.const_defined?("Project")&& Project.delete_all
  Object.const_defined?("User")   && User.delete_all

  # ActiveStorage (facultatif)
  if Object.const_defined?("ActiveStorage::Attachment") && Object.const_defined?("ActiveStorage::Blob")
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all
  end

  reset_pk_sequences!(%w[tracks scores projects users active_storage_attachments active_storage_blobs])
else
  if (u = User.find_by(email: TEST_EMAIL))
    puts " Suppression des données pour #{TEST_EMAIL}…"
    # si les relations ont des dépendances (dependent: :destroy), un simple destroy suffit
    u.projects.destroy_all
    u.destroy
    reset_pk_sequences!(%w[tracks scores projects users])
  else
    puts " Aucun utilisateur #{TEST_EMAIL} -> rien à nettoyer ciblé."
  end
end

# -- Seed --------------------------------------------------------------------
puts "==> Création des données…"

user = User.create!(
  email: TEST_EMAIL,
  password: "secret1234",
  password_confirmation: "secret1234"
)

project = user.projects.create!(title: "My Tabs")

# Score 1 — Etude (draft)
Score.create!(
  project: project,
  title:   "Etude",
  status:  :draft,
  doc: {
    schema_version: 1,
    title:  "Etude",
    tempo:  { bpm: 120, map: [] },
    tracks: [],
    measures: []
  }
)

# Score 2 — prêt (ready)
Score.create!(
  project: project,
  title:   "Let It Be (GP3)",
  status:  :ready,
  imported_format: "guitarpro",
  tempo:   140,
  doc: {
    ppq: 480,
    schema_version: 1,
    title: "Imported",
    format: "guitarpro",
    tempo: { bpm: 140, map: [] },
    time_signature: [1, 4],
    tracks: [],
    measures: []
  }
)

puts "==> Seeded:"
puts "    user:    #{user.email}"
puts "    project: #{project.title}"
puts "    scores:  #{project.scores.count}"

# ----------------------------------------------------------------------------
# NOTE :
# - Ne PAS setter preview_png_urls / preview_pdf_url / midi_url ici : ce sont
#   des champs exposés par le serializer (liés à ActiveStorage), pas des colonnes.
# - Si tu veux attacher un fichier en dev (si le modèle a has_one_attached :midi etc.) :
#     score = project.scores.last
#     score.midi.attach(io: File.open(Rails.root.join("spec/fixtures/files/demo.mid")),
#                       filename: "demo.mid",
#                       content_type: "audio/midi")
# ----------------------------------------------------------------------------
