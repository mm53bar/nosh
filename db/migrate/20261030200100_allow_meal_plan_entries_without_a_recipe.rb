class AllowMealPlanEntriesWithoutARecipe < ActiveRecord::Migration[8.1]
  def change
    change_column_null :meal_plan_entries, :recipe_id, true
    add_column :meal_plan_entries, :title, :string
  end
end
