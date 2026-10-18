class CreateAisles < ActiveRecord::Migration[8.1]
  def change
    create_table :aisles do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :aisles, :name, unique: true
  end
end
