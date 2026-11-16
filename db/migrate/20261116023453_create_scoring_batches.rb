class CreateScoringBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :scoring_batches do |t|
      t.string :anthropic_batch_id, null: false
      t.string :status, null: false, default: "submitted"
      t.string :model
      t.integer :requests_count, null: false, default: 0
      t.integer :succeeded, null: false, default: 0
      t.integer :errored, null: false, default: 0
      t.jsonb :company_ids, null: false, default: []
      t.datetime :collected_at
      t.timestamps
    end
    add_index :scoring_batches, :anthropic_batch_id, unique: true
  end
end
