require "rails_helper"

RSpec.describe ImportScoreJob, type: :job do
  let(:user)    { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:score)   { create(:score, project: project, status: :processing, imported_format: "musicxml") }

  before do
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("<score-partwise></score-partwise>"),
      filename: "file.musicxml",
      content_type: "application/xml"
    )
    score.source_file.attach(blob)

    allow(Importers::MusicXml).to receive(:call).and_return({ doc: { "title" => "OK" } })
  end

  it "met le score en ready et remplit doc" do
    perform_enqueued_jobs { described_class.perform_later(score.id) }
    expect(score.reload.status).to eq("ready")
    expect(score.doc).to include("title" => "OK")
  end
end
