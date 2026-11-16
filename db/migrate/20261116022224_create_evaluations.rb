class CreateEvaluations < ActiveRecord::Migration[8.1]
  def change
    create_table :evaluations do |t|
      t.references :company, null: false, foreign_key: true
      t.integer :staffing_score
      t.integer :automation_score
      t.string :confidence
      t.string :tier
      t.jsonb :signals, null: false, default: []
      t.jsonb :red_flags, null: false, default: []
      t.string :offshore_signal
      t.text :why_now
      t.text :lead_with
      t.string :model
      t.integer :tokens_in
      t.integer :tokens_out

      t.timestamps
    end
  end
end
