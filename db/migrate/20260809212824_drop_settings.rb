class DropSettings < ActiveRecord::Migration[8.1]
  def change
    drop_table :settings do |t|
      t.string :flaresolverr_url

      t.timestamps
    end
  end
end
