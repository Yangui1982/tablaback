class HardenProjectsAndTracksTitles < ActiveRecord::Migration[7.1]
  def up
    change_column_null :projects, :title, false
    change_column_null :tracks,   :name,  false
  end

  def down
    change_column_null :projects, :title, true
    change_column_null :tracks,   :name,  true
  end
end
