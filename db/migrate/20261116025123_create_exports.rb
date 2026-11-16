class CreateExports < ActiveRecord::Migration[8.1]
  def change
    create_table :exports do |t|
      t.string :file_format, null: false
      t.string :scope, null: false, default: "view"
      t.jsonb :filters, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.integer :row_count
      t.text :error
      t.string :filename
      t.string :content_type
      t.binary :data
      t.timestamps
    end
    add_index :exports, :created_at
  end
end
