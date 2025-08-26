# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
user = User.find_or_create_by!(email: 'test@exemple.com') do |u|
  u.password = 'secret1234'
end

project = user.projects.find_or_create_by!(title: 'My Tabs')

Score.find_or_create_by!(project: project, title: 'Etude') do |s|
  s.status = :draft
  s.doc = { schema_version: 1, title: 'Etude', tempo: { bpm: 120, map: [] }, tracks: [], measures: [] }
end

puts "Seeded: user=#{user.email}, project=#{project.title}"
