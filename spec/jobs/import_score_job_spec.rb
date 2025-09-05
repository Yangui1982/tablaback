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

  let(:project) { create(:project) }

  # Helper: fabrique un score EN DRAFT (sinon le job idempotent skip)
  def build_score_with_source(
    imported_format: "guitarpro",
    filename: "foo.gp3",
    content_type: "application/octet-stream",
    body: "GPBIN"
  )
    score = create(:score, project:, imported_format:, status: :draft, doc: {})
    score.source_file.attach(
      io: StringIO.new(body),
      filename: filename,
      content_type: content_type
    )
    score
  end

  # --- Stubs MuseScore CLI pour éviter la dépendance système en test ----------
  # Le pipeline canon écrit un .MXL → on copie une vraie fixture .mxl
  def stub_musescore_success!
    allow_any_instance_of(MusescoreCli).to receive(:to_musicxml) do |_, in_path, out_path|
      # out_path se termine par .mxl dans notre job → on doit produire un zip MXL valide
      FileUtils.cp(FIXTURE_MXL, out_path)
    end

    allow_any_instance_of(MusescoreCli).to receive(:to_midi) do |_, _in_path, out_path|
      # header MIDI minimal
      File.binwrite(out_path, "MThd" + ("\x00" * 10))
    end

    allow_any_instance_of(MusescoreCli).to receive(:to_pdf) do |_, _in_path, out_path|
      File.binwrite(out_path, "%PDF-1.4\n%stub\n")
    end

    allow_any_instance_of(MusescoreCli).to receive(:to_pngs) do |_, _in_path, pattern|
      File.binwrite(pattern.sub("page", "page-1"), "\x89PNG\r\n\x1A\nstub")
    end
  end

  it "s'enfile" do
    expect {
      described_class.perform_later(123)
    }.to have_enqueued_job(described_class).with(123).on_queue(described_class.queue_name)
  end

  it "décompresse un .mxl en .musicxml valide" do
    mxl = FIXTURE_MXL
    out = Tempfile.new(["out", ".musicxml"])
    job = described_class.new
    job.send(:extract_mxl_to_xml, mxl, out.path)

    xml = File.read(out.path)
    expect(xml).to include("<score-partwise").or include("<score-timewise")
  end

  context "pipeline heureux (MuseScore stub)" do
    before { stub_musescore_success! }

    it "canonise, génère les assets, indexe, met en ready et renseigne imported_format" do
      score = build_score_with_source(imported_format: "guitarpro", filename: "foo.gp3")

      described_class.perform_now(score.id)
      score.reload

      expect(score).to be_ready
      expect(score.normalized_mxl).to be_attached
      expect(score.export_midi_file).to be_attached
      expect(score.preview_pdf).to be_attached
      expect(score.preview_pngs).to be_attached

      expect(score.doc).to be_present
      expect(score.tempo).to be_present
      expect(score.imported_format).to eq("guitarpro").or eq("musicxml")
    end

    it "idempotence : ignore si déjà ready (pas d'appel MuseScore)" do
      score = build_score_with_source
      score.update!(status: :ready, doc: { "pre" => 1 })

      expect_any_instance_of(MusescoreCli).not_to receive(:to_musicxml)
      described_class.perform_now(score.id)

      score.reload
      expect(score).to be_ready
      expect(score.doc).to eq({ "pre" => 1 })
    end
  end

  # spec/jobs/import_score_job_spec.rb

  if ENV["RUN_REAL_MUSESCORE"] == "1"
    describe "import réel GP3 (sans stub)" do
      it "importe un vrai .gp3 et met le score en ready" do
        score = create(:score, imported_format: "guitarpro", status: :draft)
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
      end
    end
  end


  describe "échecs" do
    it "fichier manquant -> failed + import_error" do
      score = create(:score, project:, imported_format: "musicxml", status: :draft)
      # pas d'attachement source_file

      expect {
        described_class.perform_now(score.id)
      }.to raise_error(RuntimeError, "source_file_missing")

      score.reload
      expect(score).to be_failed
      expect(score.import_error).to eq("source_file_missing")
    end

    it "format non supporté -> failed + import_error" do
      # status :draft pour que le job n'ignore pas, imported_format 'unknown' pour déclencher l'erreur
      score = create(:score, project:, imported_format: "unknown", status: :draft)

      # ATTACH + RELOAD pour s'assurer que l'attachment est bien persisté
      score.source_file.attach(
        io: File.open(FIXTURE_MXL, "rb"),
        filename: "ok.mxl",
        content_type: "application/vnd.recordare.musicxml"  # autorisé par ALLOWED_SOURCE_TYPES
      )
      score.reload
      expect(score.source_file).to be_attached   # garde-fou utile

      expect {
        described_class.perform_now(score.id)
      }.to raise_error(RuntimeError, "unsupported_format")

      score.reload
      expect(score.status).to eq("failed")
      expect(score.import_error).to eq("unsupported_format")
    end

    it "MuseScore lève une erreur -> failed + import_error" do
      score = build_score_with_source
      allow_any_instance_of(MusescoreCli).to receive(:to_musicxml).and_raise(MusescoreCli::Error, "boom")

      expect {
        described_class.perform_now(score.id)
      }.to raise_error(MusescoreCli::Error, "boom")

      score.reload
      expect(score).to be_failed
      expect(score.import_error).to be_present
    end

    it "timeout de la canonisation -> failed + import_error" do
      score = build_score_with_source(
        imported_format: "musicxml",
        filename: "ok.musicxml",
        content_type: "application/xml",
        body: "<xml/>"
      )

      allow_any_instance_of(described_class).to receive(:parse_timeout_seconds).and_return(0.01)
      allow_any_instance_of(described_class).to receive(:canonize_and_generate_assets!) { sleep 0.1 }

      expect {
        described_class.perform_now(score.id)
      }.to raise_error(Timeout::Error)  # <— au lieu de RuntimeError("import_timeout")

      score.reload
      expect(score).to be_failed
      expect(score.import_error).to be_present
    end
  end
end
