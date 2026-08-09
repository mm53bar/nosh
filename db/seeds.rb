# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# This household's actual kitchen equipment (per ~/projects/recipes/CLAUDE.md, the ops workspace
# for this app) — seeded as owned so the Equipment sidebar facet and recipe/technique edit forms
# have real options from day one, not an empty list.
HOUSEHOLD_EQUIPMENT = [
  "Cuisinart food processor",
  "Philips pasta maker",
  "KitchenAid mixer",
  "Vitamix",
  "Ninja Foodi dual air fryer",
  "Instant Pot",
  "Weber gas BBQ",
  "Camp Chef pizza oven"
].freeze

HOUSEHOLD_EQUIPMENT.each do |name|
  Equipment.find_or_create_by!(name: name).update!(owned: true)
end
