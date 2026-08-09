class CreateTechniqueEquipments < ActiveRecord::Migration[8.1]
  def change
    create_table :technique_equipments do |t|
      t.references :technique, null: false, foreign_key: true
      t.references :equipment, null: false, foreign_key: true

      t.timestamps
    end

    add_index :technique_equipments, [ :technique_id, :equipment_id ], unique: true
  end
end
