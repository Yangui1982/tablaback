module ScoreDefaults
  extend ActiveSupport::Concern

  def default_doc(raw_title)
    title = raw_title.to_s.strip
    title = "Untitled" if title.blank?
    {
      schema_version: 1,
      title: title,
      tempo: { bpm: 120, map: [] },
      tracks: [],
      measures: []
    }
  end
end
