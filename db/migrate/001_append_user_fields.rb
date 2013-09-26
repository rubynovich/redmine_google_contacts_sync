class AppendUserFields < ActiveRecord::Migration
  def change
    add_column :users, :google_contact_id, :string
    add_column :users, :last_google_sync_at, :datetime, :default => '2000-01-01'.to_time
    add_column :users, :must_google_sync, :boolean, :default => true
    add_index :users, :must_google_sync
  end

end
