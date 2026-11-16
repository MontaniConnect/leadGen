class AddOutreachStateToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :connection_sent_at, :datetime
    add_column :companies, :reply_result, :string
    add_index :companies, :reply_result
  end
end
