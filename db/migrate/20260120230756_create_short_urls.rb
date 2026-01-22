class CreateShortUrls < ActiveRecord::Migration[5.2]
  def change
    create_table :short_urls do |t|
      t.string :original_url, null: false, limit: 2048
      t.string :code, null: false, limit: 32

      t.timestamps
    end

    add_index :short_urls, :original_url, unique: true
    add_index :short_urls, :code, unique: true
  end
end
