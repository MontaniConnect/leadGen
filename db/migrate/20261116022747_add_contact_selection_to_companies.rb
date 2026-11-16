class AddContactSelectionToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :contact_status, :string, null: false, default: "pending"
    add_reference :companies, :selected_contact, foreign_key: { to_table: :contacts, on_delete: :nullify }
    add_index :companies, :contact_status
  end
end
