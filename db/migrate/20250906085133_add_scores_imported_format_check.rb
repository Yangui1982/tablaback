class AddScoresImportedFormatCheck < ActiveRecord::Migration[7.1]
  CONSTRAINT_NAME = "scores_imported_format_check".freeze
  ALLOWED = %w[mxl musicxml guitarpro].freeze

  def up
    execute <<~SQL
      UPDATE scores
      SET imported_format = NULL
      WHERE imported_format IS NOT NULL
        AND imported_format NOT IN (#{ALLOWED.map { |v| "'#{v}'" }.join(", ")});
    SQL

    execute <<~SQL
      ALTER TABLE scores
      ADD CONSTRAINT #{CONSTRAINT_NAME}
      CHECK (imported_format IN (#{ALLOWED.map { |v| "'#{v}'" }.join(", ")}) OR imported_format IS NULL);
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE scores
      DROP CONSTRAINT IF EXISTS #{CONSTRAINT_NAME};
    SQL
  end
end
