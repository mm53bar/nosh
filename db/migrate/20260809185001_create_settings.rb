class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :flaresolverr_url

      t.timestamps
    end
  end
end
