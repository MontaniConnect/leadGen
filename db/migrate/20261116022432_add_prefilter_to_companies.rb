class AddPrefilterToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :prefilter_status, :string, null: false, default: "pending"
    add_column :companies, :prefilter_reasons, :jsonb, null: false, default: []
    add_column :companies, :prefilter_boosts, :jsonb, null: false, default: []
    add_column :companies, :prefilter_score, :integer, null: false, default: 0
    add_column :companies, :prefiltered_at, :datetime
    add_index :companies, :prefilter_status
  end
end
