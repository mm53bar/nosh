class ShoppingListItem < ApplicationRecord
  CATEGORIES = [ "Produce", "Dairy & Eggs", "Fridge", "Pantry & Dry Goods", "Frozen" ].freeze

  belongs_to :staple, optional: true

  validates :name, presence: true

  # Ingredients that are staples are shown as markers on their tab, not as lines
  # of their own — see docs/adr/20261018-shopping-list-is-a-staples-board.md.
  scope :this_week, -> { where(staple_id: nil) }

  # HelloFresh imports count things with the literal unit "unit" — "2 unit".
  def quantity = [ amount, (unit unless unit == "unit") ].compact_blank.join(" ")

  # A bare "2" in a badge reads as a notification count, not two of something.
  def marker_label = quantity.match?(/\A[\d.\/¼½¾]+\z/) ? "×#{quantity}" : quantity
end
