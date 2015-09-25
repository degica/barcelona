class RenameValueToEncryptedValue < ActiveRecord::Migration
  def change
    remove_column :env_vars, :value
    add_column :env_vars, :encrypted_value, :text
  end
end
