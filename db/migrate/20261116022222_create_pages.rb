class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.references :company, null: false, foreign_key: true
      t.string :url
      t.string :kind
      t.text :text
      t.datetime :fetched_at
      t.string :status, null: false, default: "pending"

      t.timestamps
    end
  end
end
