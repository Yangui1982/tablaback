require "rails_helper"

RSpec.describe ImportScoreJob, type: :job do
  include ActiveJob::TestHelper

  before do
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = false
    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = false
    clear_enqueued_jobs

    sentry_scope = double("SentryScope", set_tags: nil, set_extras: nil)
    if defined?(Sentry)
      allow(Sentry).to receive(:capture_exception)
      allow(Sentry).to receive(:with_scope).and_yield(sentry_scope)
    else
      stub_const("Sentry", Module.new)
      Sentry.define_singleton_method(:capture_exception) { |_e, **_k| nil }
      Sentry.define_singleton_method(:with_scope) { |&blk| blk.call(sentry_scope) }
    end
  end

  after { clear_enqueued_jobs }

  let(:musicxml_score) do
    create(:score, imported_format: "musicxml").tap do |s|
      s.source_file.attach(
        io: StringIO.new("<xml/>"),
        filename: "t.musicxml",
        content_type: "application/xml"
      )
    end
  end

  it "s'enfile" do
    expect {
      described_class.perform_later(123)
    }.to have_enqueued_job(described_class).with(123).on_queue(described_class.queue_name)
  end

  context "succès avec stub du parseur" do
    before do
      allow_any_instance_of(described_class)
        .to receive(:parse_file)
        .and_return(doc: { "ok" => true })
    end

    it "normalise le doc (format par défaut si absent)" do
      described_class.perform_now(musicxml_score.id)
      musicxml_score.reload
      expect(musicxml_score.doc["ok"]).to eq(true)
      expect(musicxml_score.doc["format"]).to eq("musicxml")
      expect(musicxml_score).to be_ready
    end

    it "respecte le format fourni par le payload" do
      allow_any_instance_of(described_class)
        .to receive(:parse_file)
        .and_return(doc: { "x" => 1, "format" => "guitarpro" })

      described_class.perform_now(musicxml_score.id)
      musicxml_score.reload
      expect(musicxml_score.doc["format"]).to eq("guitarpro")
    end

    it "emballe un doc non-Hash dans { 'data' => ... }" do
      allow_any_instance_of(described_class)
        .to receive(:parse_file)
        .and_return(doc: "RAW", format: "guitarpro")

      described_class.perform_now(musicxml_score.id)
      musicxml_score.reload
      expect(musicxml_score.doc).to include("data" => "RAW", "format" => "guitarpro")
    end
  end

  describe "import réel GP3 (sans stub)" do
    it "importe un vrai .gp3 et met le score en ready" do
      score = create(:score, imported_format: "guitarpro")
      file  = Rails.root.join("spec/fixtures/files/the-beatles-let_it_be.gp3")

      score.source_file.attach(
        io: File.open(file, "rb"),
        filename: "the-beatles-let_it_be.gp3",
        content_type: "application/octet-stream"
      )

      described_class.perform_now(score.id)

      score.reload
      expect(score).to be_ready
      expect(score.doc).to be_present
      expect(score.doc["format"]).to eq("guitarpro")
    end
  end

  describe "échecs" do
    it "fichier manquant -> failed + import_error" do
      score = create(:score, imported_format: "musicxml")

      expect {
        described_class.perform_now(score.id)
      }.to raise_error(RuntimeError, "source_file_missing")

      score.reload
      expect(score).to be_failed
      expect(score.import_error).to eq("source_file_missing")
    end

    it "échecs format non supporté -> failed + import_error" do
      s = create(:score, imported_format: "unknown")
      s.source_file.attach(
        io: StringIO.new("<xml/>"),
        filename: "ok.musicxml",
        content_type: "application/xml"
      )
      s.reload
      expect(s.source_file).to be_attached

      expect {
        described_class.perform_now(s.id)
      }.to raise_error(RuntimeError, "unsupported_format")

      s.reload
      expect(s.status).to eq("failed")
      expect(s.import_error).to eq("unsupported_format")
    end

    it "parseur lève une exception -> failed + import_error" do
      score = musicxml_score
      allow_any_instance_of(described_class)
        .to receive(:parse_file)
        .and_raise(StandardError, "boom")

      expect {
        described_class.perform_now(score.id)
      }.to raise_error(StandardError, "boom")

      score.reload
      expect(score).to be_failed
      expect(score.import_error).to eq("boom")
    end

    it "timeout du parse -> failed + import_error=import_timeout" do
      score = musicxml_score

      allow_any_instance_of(described_class)
        .to receive(:parse_timeout_seconds)
        .and_return(0.01)

      allow_any_instance_of(described_class)
        .to receive(:parse_file) { sleep 0.1 }

      expect {
        described_class.perform_now(score.id)
      }.to raise_error(RuntimeError, "import_timeout")

      score.reload
      expect(score).to be_failed
      expect(score.import_error).to eq("import_timeout")
    end
  end

  describe "idempotence" do
    it "ignore si le score est déjà ready" do
      score = musicxml_score
      score.update!(status: :ready, doc: { "pre" => 1 })

      expect_any_instance_of(described_class).not_to receive(:parse_file)

      described_class.perform_now(score.id)

      score.reload
      expect(score).to be_ready
      expect(score.doc).to eq({ "pre" => 1 })
    end
  end
end
