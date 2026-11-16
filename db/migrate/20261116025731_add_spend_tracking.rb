class AddSpendTracking < ActiveRecord::Migration[8.1]
  def change
    add_column :evaluations, :cost_usd, :decimal, precision: 12, scale: 6, null: false, default: 0
    add_reference :evaluations, :pipeline_run, foreign_key: { on_delete: :nullify }
    add_column :draft_runs, :cost_usd, :decimal, precision: 12, scale: 6, null: false, default: 0
    add_reference :draft_runs, :pipeline_run, foreign_key: { on_delete: :nullify }
    add_column :scoring_batches, :reserved_usd, :decimal, precision: 12, scale: 6, null: false, default: 0
    add_reference :scoring_batches, :pipeline_run, foreign_key: { on_delete: :nullify }
  end
end
