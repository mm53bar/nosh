class BringBackSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.text :dinner_slate_notes
      t.timestamps
    end
  end
end
