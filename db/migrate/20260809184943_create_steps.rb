class CreateSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :steps do |t|
      t.references :recipe, null: false, foreign_key: true
      t.text :instruction, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :steps, [ :recipe_id, :position ]
  end
end
