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

    allow_any_instance_of(ImportScoreJob)
      .to receive(:parse_file)
      .and_return(doc: { "ok" => true })
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
    expect(score.doc).to include("ok" => true, "format" => "musicxml")
  end
end
