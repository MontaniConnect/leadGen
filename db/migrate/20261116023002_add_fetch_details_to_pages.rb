class AddFetchDetailsToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :http_status, :integer
    add_column :pages, :discovered_urls, :jsonb, null: false, default: {}
    add_column :pages, :word_count, :integer, null: false, default: 0
    add_index :pages, %i[company_id kind], unique: true
  end
end
