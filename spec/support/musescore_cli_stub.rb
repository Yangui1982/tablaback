# spec/support/musescore_cli_stub.rb
FIXTURE_MXL = Rails.root.join("spec/fixtures/files/la-mer-trenetlasry.mxl")

RSpec.configure do |config|
  config.before(:each) do
    # Export "MusicXML" : dans notre job on demande un .mxl (canon).
    # Si un test demande un .musicxml, on renvoie un XML minimal valide.
    allow_any_instance_of(MusescoreCli).to receive(:to_musicxml) do |_, _in_path, out_path|
      if out_path.to_s =~ /\.mxl\z/i
        FileUtils.cp(FIXTURE_MXL, out_path)              # <-- .mxl valide
      else
        File.binwrite(out_path, <<~XML)                  # <-- fallback .musicxml simple
          <?xml version="1.0" encoding="UTF-8"?>
          <score-partwise version="3.1" xmlns="http://www.musicxml.org/ns/musicxml">
            <part-list><score-part id="P1"><part-name>Guitar</part-name></score-part></part-list>
            <part id="P1"><measure number="1">
              <attributes><divisions>1</divisions></attributes>
              <direction><sound tempo="120"/></direction>
              <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration></note>
              <note><chord/><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration></note>
            </measure></part>
          </score-partwise>
        XML
      end
    end

    allow_any_instance_of(MusescoreCli).to receive(:to_midi) do |_, _in_path, out_path|
      # Header MIDI minimal
      File.binwrite(out_path, "MThd" + ("\x00" * 10))
    end

    allow_any_instance_of(MusescoreCli).to receive(:to_pdf) do |_, _in_path, out_path|
      File.binwrite(out_path, "%PDF-1.4\n%stub\n")
    end

    allow_any_instance_of(MusescoreCli).to receive(:to_pngs) do |_, _in_path, pattern|
      File.binwrite(pattern.sub("page", "page-1"), "\x89PNG\r\n\x1A\nstub")
    end
  end
end
