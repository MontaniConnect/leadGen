class CreateDraftRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :draft_runs do |t|
      t.references :company, null: false, foreign_key: true
      t.string :status, null: false, default: "ok"
      t.text :error
      t.string :model
      t.string :prompt_version
      t.integer :tokens_in, null: false, default: 0
      t.integer :tokens_out, null: false, default: 0
      t.integer :cache_read_tokens, null: false, default: 0
      t.integer :cache_write_tokens, null: false, default: 0
      t.jsonb :raw, null: false, default: {}
      t.timestamps
    end
    add_index :draft_runs, %i[company_id status]
  end
end
