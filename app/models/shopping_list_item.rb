class ShoppingListItem < ApplicationRecord
  CATEGORIES = [ "Produce", "Dairy & Eggs", "Fridge", "Pantry & Dry Goods", "Frozen" ].freeze

  validates :name, presence: true
end
