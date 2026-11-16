class AddPartnerDismissedAtToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :partner_dismissed_at, :datetime
  end
end
