class AddIndexScoresImportedFormat < ActiveRecord::Migration[7.1]
  def change
    add_index :scores, :imported_format
  end
end
