class AddDetailsToFlags < ActiveRecord::Migration[8.1]
  def change
    add_column :flags, :details, :text
  end
end
