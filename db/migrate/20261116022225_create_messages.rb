class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :company, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.string :label
      t.text :body
      t.string :status, null: false, default: "draft"

      t.timestamps
    end
  end
end
