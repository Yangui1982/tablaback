module ScoreDefaults
  extend ActiveSupport::Concern

  DEFAULT_PPQ  = 480
  DEFAULT_SIG  = [4, 4]
  DEFAULT_BPM  = 120

  def default_doc(raw_title)
    title = raw_title.to_s.strip
    title = "Untitled" if title.blank?
    {
      "schema_version" => 1,
      "title"          => title,
      "ppq"            => DEFAULT_PPQ,
      "tempo_bpm"      => DEFAULT_BPM,
      "time_signature" => DEFAULT_SIG,
      # éléments “hérités” si tu les utilises ailleurs :
      "tempo"          => { "bpm" => DEFAULT_BPM, "map" => [] },
      "measures"       => [],
      # partition vide autorisée :
      "tracks"         => [] # [{ "name"=>..., "channel"=>0, "program"=>25, "notes"=>[{start,duration,pitch,velocity}, ...] }]
    }
  end
end
