class HardenDocAndChecksumOnScores < ActiveRecord::Migration[7.1]
  def up
    execute "UPDATE scores SET doc = '{}'::jsonb WHERE doc IS NULL;"
    change_column :scores, :doc, :jsonb, null: false, default: {}
    add_index :scores, :doc, using: :gin

    add_column :scores, :doc_checksum, :string unless column_exists?(:scores, :doc_checksum)
    add_index  :scores, :doc_checksum unless index_exists?(:scores, :doc_checksum)
  end

  def down
    remove_index :scores, :doc if index_exists?(:scores, :doc)
    change_column :scores, :doc, :jsonb, null: true, default: nil
    remove_index :scores, :doc_checksum if index_exists?(:scores, :doc_checksum)
    remove_column :scores, :doc_checksum if column_exists?(:scores, :doc_checksum)
  end
end
