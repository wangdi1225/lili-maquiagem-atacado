class AddMissingAuthColumnsToSpreeUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_users, :deleted_at, :datetime unless column_exists?(:spree_users, :deleted_at)
    add_column :spree_users, :confirmation_token, :string unless column_exists?(:spree_users, :confirmation_token)
    add_column :spree_users, :confirmed_at, :datetime unless column_exists?(:spree_users, :confirmed_at)
    add_column :spree_users, :confirmation_sent_at, :datetime unless column_exists?(:spree_users, :confirmation_sent_at)
    add_column :spree_users, :unconfirmed_email, :string unless column_exists?(:spree_users, :unconfirmed_email)
    add_index :spree_users, :deleted_at unless index_exists?(:spree_users, :deleted_at)
  end
end
