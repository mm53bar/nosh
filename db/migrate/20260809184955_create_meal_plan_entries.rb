class CreateMealPlanEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :meal_plan_entries do |t|
      t.date :date, null: false
      t.references :recipe, null: false, foreign_key: true
      t.integer :servings
      t.text :notes

      t.timestamps
    end

    add_index :meal_plan_entries, :date
  end
end
