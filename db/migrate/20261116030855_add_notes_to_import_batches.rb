class AddNotesToImportBatches < ActiveRecord::Migration[8.1]
  def change
    add_column :import_batches, :notes, :jsonb, null: false, default: {}
  end
end
