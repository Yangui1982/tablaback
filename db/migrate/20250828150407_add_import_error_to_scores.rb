class AddImportErrorToScores < ActiveRecord::Migration[7.1]
  def change
    add_column :scores, :import_error, :text
  end
end
