require "zip"

module MxlHelper
  # Crée un .mxl valide dans `path`, avec un fichier principal "score.musicxml"
  def build_mxl_with(xml_str, path:)
    FileUtils.mkdir_p(File.dirname(path))
    Zip::File.open(path, create: true) do |zip|
      zip.get_output_stream("META-INF/container.xml") do |io|
        io.write <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
              <rootfile full-path="score.musicxml" media-type="application/vnd.recordare.musicxml+xml"/>
            </rootfiles>
          </container>
        XML
      end
      zip.get_output_stream("score.musicxml") { |io| io.write xml_str }
    end
    path
  end

  def minimal_musicxml(title: "Imported")
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE score-partwise PUBLIC
        "-//Recordare//DTD MusicXML 3.1 Partwise//EN"
        "http://www.musicxml.org/dtds/partwise.dtd">
      <score-partwise version="3.1">
        <work><work-title>#{title}</work-title></work>
        <part-list>
          <score-part id="P1"><part-name>Guitar</part-name></score-part>
        </part-list>
        <part id="P1">
          <measure number="1">
            <attributes>
              <divisions>1</divisions>
              <time><beats>4</beats><beat-type>4</beat-type></time>
              <key><fifths>0</fifths></key>
              <clef><sign>G</sign><line>2</line></clef>
            </attributes>
            <direction placement="above"><sound tempo="120"/></direction>
            <note>
              <pitch><step>C</step><octave>4</octave></pitch>
              <duration>1</duration>
              <type>quarter</type>
            </note>
            <note>
              <pitch><step>E</step><octave>4</octave></pitch>
              <duration>1</duration>
              <type>quarter</type>
            </note>
            <note>
              <pitch><step>G</step><octave>4</octave></pitch>
              <duration>1</duration>
              <type>quarter</type>
            </note>
            <note>
              <pitch><step>C</step><octave>5</octave></pitch>
              <duration>1</duration>
              <type>quarter</type>
            </note>
          </measure>
        </part>
      </score-partwise>
    XML
  end
end

RSpec.configure { |c| c.include MxlHelper }
