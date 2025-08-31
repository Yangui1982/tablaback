RSpec.describe MidiRenderService do
  it "génère un header MIDI valide" do
    doc = {
      "ppq"=>480, "tempo_bpm"=>120, "time_signature"=>[4,4],
      "tracks"=>[{"name"=>"Test","channel"=>0,"program"=>0,
                  "notes"=>[{"start"=>0,"duration"=>480,"pitch"=>60,"velocity"=>80}]}]
    }
    data = described_class.new(doc: doc, title: "Hello").call
    expect(data.bytes.first(4)).to eq([0x4D,0x54,0x68,0x64]) # "MThd"
  end

  it "lève empty_score si aucune note" do
    doc = { "ppq"=>480, "tempo_bpm"=>120, "time_signature"=>[4,4], "tracks"=>[] }
    expect { described_class.new(doc: doc).call }.to raise_error(ArgumentError, "empty_score")
  end
end
