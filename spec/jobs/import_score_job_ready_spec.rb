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

    # 🔁 Nouveau stub : on simule la canonisation + génération des assets
    allow_any_instance_of(ImportScoreJob)
      .to receive(:canonize_and_generate_assets!)
      .and_wrap_original do |_, sc, imported_format|
        # on simule un index minimal valide
        sc.doc = {
          "format"     => (imported_format.presence || "musicxml"),
          "tempo_bpm"  => 120,
          "time_signature" => [4, 4],
          "tracks" => [
            {
              "name" => "Guitar",
              "channel" => 1,
              "program" => 25,
              "notes" => [
                { "start" => 0, "duration" => 480, "pitch" => 60, "velocity" => 90 }
              ]
            }
          ]
        }
        sc.update!(tempo: 120)
        sc.update!(duration_ticks: sc.compute_duration_ticks)
        sc.sync_tracks_from_doc!
        # on simule un MIDI attaché (facultatif pour cette spec)
        midi_bytes = MidiRenderService.new(doc: sc.doc, title: sc.title).call
        sc.attach_midi!(midi_bytes, filename: "stub.mid")
      end
  end

  after { clear_enqueued_jobs }

  let(:score) do
    create(:score, imported_format: "musicxml").tap do |s|
      s.source_file.attach(
        io: StringIO.new("<xml/>"),
        filename: "t.musicxml",
        content_type: "application/xml"
      )
    end
  end

  it "met le score en ready et remplit doc" do
    described_class.perform_now(score.id)
    score.reload
    expect(score.status).to eq("ready")
    expect(score.doc).to include("format" => "musicxml", "tempo_bpm" => 120)
    # un petit extra utile :
    expect(score.export_midi_file).to be_attached
    expect(score.tracks.count).to be >= 1
  end
end
