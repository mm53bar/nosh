class CreateRecipeTechniques < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_techniques do |t|
      t.references :recipe, null: false, foreign_key: true
      t.references :technique, null: false, foreign_key: true

      t.timestamps
    end

    add_index :recipe_techniques, [ :recipe_id, :technique_id ], unique: true
  end
end
