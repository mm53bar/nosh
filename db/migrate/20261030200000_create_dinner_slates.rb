class CreateDinnerSlates < ActiveRecord::Migration[8.1]
  def change
    create_table :dinner_slates do |t|
      t.date :week_start, null: false
      t.string :status, null: false
      t.json :ideas, null: false, default: []
      t.string :error
      t.datetime :seen_at
      t.timestamps
    end
    add_index :dinner_slates, [ :week_start, :created_at ]
  end
end
