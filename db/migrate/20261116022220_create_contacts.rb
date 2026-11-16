class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts do |t|
      t.references :company, null: false, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :title
      t.string :linkedin_url
      t.string :email
      t.string :source, null: false, default: "apollo"

      t.timestamps
    end
  end
end
