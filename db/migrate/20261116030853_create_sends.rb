class CreateSends < ActiveRecord::Migration[8.1]
  def change
    create_table :sends do |t|
      t.references :company, null: false, foreign_key: true, index: { unique: true }
      t.references :contact, foreign_key: { on_delete: :nullify }
      t.references :message, foreign_key: { on_delete: :nullify }
      t.string :variant
      t.string :assignment, null: false, default: "random"
      t.datetime :connection_sent_at, null: false
      t.boolean :connection_accepted, null: false, default: false
      t.text :sent_body
      t.integer :word_count
      t.datetime :sent_at
      t.boolean :replied, null: false, default: false
      t.boolean :positive_reply, null: false, default: false
      t.boolean :call_booked, null: false, default: false
      t.datetime :replied_at
      # Snapshot of the lead when the connection request was sent
      t.string :tier
      t.integer :staffing_score
      t.integer :automation_score
      t.string :confidence
      t.string :industry
      t.integer :employee_count
      t.string :contact_title
      t.boolean :had_why_now, null: false, default: false
      t.jsonb :signal_tags, null: false, default: []
      t.timestamps
    end
    add_index :sends, :variant
    add_index :sends, :tier
    add_index :sends, :sent_at
  end
end
