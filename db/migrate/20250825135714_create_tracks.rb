class CreateTracks < ActiveRecord::Migration[7.1]
  def change
    create_table :tracks do |t|
      t.references :score, null: false, foreign_key: true
      t.string :name
      t.string :instrument
      t.string :tuning
      t.integer :capo
      t.integer :channel

      t.timestamps
    end
  end
end
