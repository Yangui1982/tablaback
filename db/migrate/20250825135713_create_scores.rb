class CreateScores < ActiveRecord::Migration[7.1]
  def change
    create_table :scores do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title
      t.string :status
      t.string :imported_format
      t.string :key_sig
      t.string :time_sig
      t.integer :tempo
      t.jsonb :doc

      t.timestamps
    end
  end
end
