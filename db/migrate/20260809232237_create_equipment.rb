class CreateEquipment < ActiveRecord::Migration[8.1]
  def change
    create_table :equipment do |t|
      t.string :name, null: false
      t.boolean :owned, null: false, default: false

      t.timestamps
    end

    add_index :equipment, :name, unique: true
  end
end
