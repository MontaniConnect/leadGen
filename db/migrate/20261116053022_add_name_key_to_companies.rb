class AddNameKeyToCompanies < ActiveRecord::Migration[8.1]
  def up
    add_column :companies, :name_key, :string
    add_index :companies, :name_key
    Company.reset_column_information
    Company.find_each { |company| company.update_columns(name_key: Imports::NameKey.call(company.name)) }
  end

  def down
    remove_column :companies, :name_key
  end
end
