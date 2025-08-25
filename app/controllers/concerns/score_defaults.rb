module ScoreDefaults
  extend ActiveSupport::Concern

  def default_doc(title = "Untitled")
    { "schema_version" => 1, "title" => title,
      "tempo" => { "bpm" => 120, "map" => [] },
      "tracks" => [], "measures" => [] }
  end
end
