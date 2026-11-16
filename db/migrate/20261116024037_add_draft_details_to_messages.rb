class AddDraftDetailsToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :word_count, :integer, null: false, default: 0
    add_column :messages, :evidence, :text
    add_column :messages, :model, :string
    add_column :messages, :prompt_version, :string
    add_reference :messages, :draft_run, foreign_key: { on_delete: :nullify }
    add_index :messages, %i[company_id label]
  end
end
