class AddContactResearchToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :contact_researched_at, :datetime
    add_column :companies, :contact_research_result, :string
  end
end
