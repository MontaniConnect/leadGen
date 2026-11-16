class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.references :import_batch, foreign_key: true
      t.string :name
      t.string :account_stage
      t.integer :employees
      t.string :industry
      t.string :website
      t.string :domain
      t.string :linkedin_url
      t.string :city
      t.string :state
      t.string :country
      t.text :keywords
      t.text :technologies
      t.bigint :total_funding
      t.string :latest_funding
      t.bigint :latest_funding_amount
      t.date :last_raised_at
      t.bigint :annual_revenue
      t.string :apollo_account_id
      t.string :sic_codes
      t.string :naics_codes
      t.text :short_description
      t.integer :founded_year
      t.string :intent_topic
      t.integer :intent_score
      t.jsonb :extra, null: false, default: {}

      t.timestamps
    end
    add_index :companies, :apollo_account_id, unique: true
    add_index :companies, :domain
  end
end
