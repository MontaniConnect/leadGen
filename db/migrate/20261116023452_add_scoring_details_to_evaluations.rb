class AddScoringDetailsToEvaluations < ActiveRecord::Migration[8.1]
  def change
    add_column :evaluations, :status, :string, null: false, default: "ok"
    add_column :evaluations, :error, :text
    add_column :evaluations, :disqualified, :boolean, null: false, default: false
    add_column :evaluations, :why_now_source, :string
    add_column :evaluations, :prompt_version, :string
    add_column :evaluations, :useful_sources, :integer
    add_column :evaluations, :cache_read_tokens, :integer, null: false, default: 0
    add_column :evaluations, :cache_write_tokens, :integer, null: false, default: 0
    add_column :evaluations, :raw, :jsonb, null: false, default: {}
    add_index :evaluations, %i[company_id status]
    add_index :evaluations, :tier
  end
end
