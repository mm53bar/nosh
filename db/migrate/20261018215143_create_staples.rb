class CreateStaples < ActiveRecord::Migration[8.1]
  def change
    create_table :staples do |t|
      t.string :name, null: false
      t.references :aisle, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.boolean :needed, null: false, default: false
      t.string :group_name
      t.string :note
      t.json :aliases, null: false, default: []

      t.timestamps
    end
    add_index :staples, :name, unique: true
  end
end
