class CreateWriteIns < ActiveRecord::Migration[8.1]
  def change
    create_table :write_ins do |t|
      t.string :name, null: false
      t.datetime :bought_at

      t.timestamps
    end
  end
end
