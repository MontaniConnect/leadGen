class CreateImportBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :import_batches do |t|
      t.string :kind, null: false
      t.string :filename
      t.string :status, null: false, default: "pending"
      t.integer :rows_total, null: false, default: 0
      t.integer :rows_created, null: false, default: 0
      t.integer :rows_updated, null: false, default: 0
      t.integer :rows_skipped, null: false, default: 0
      t.jsonb :skip_reasons, null: false, default: {}
      t.jsonb :skipped_rows, null: false, default: []

      t.timestamps
    end
  end
end
