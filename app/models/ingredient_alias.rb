# A settled decision that two ingredient names are one thing to buy:
# "scallions" is "green onions". Recording it renames every ingredient already
# using the variant, and Ingredient applies it on create, so an import can't
# bring a settled name back. Exact names only, ignoring case and spacing —
# which near-misses are the same product is the ingredient audit's judgment.
# See docs/adr/20261025-ingredient-aliases-apply-on-create.md.
class IngredientAlias < ApplicationRecord
  attr_reader :renamed

  before_validation :normalize
  validates :variant, presence: true, uniqueness: true
  validates :canonical, presence: true
  validate :not_its_own_canonical

  after_save :rename_ingredients

  def self.key(name) = name.to_s.squish.downcase

  def self.canonical_for(name) = find_by(variant: key(name))&.canonical

  private

  # Aliases stay one hop deep: a canonical that is itself a variant resolves to
  # its own canonical, and aliases that pointed at this variant follow it.
  def normalize
    self.variant = self.class.key(variant)
    self.canonical = canonical.to_s.squish
    @resolved = self.class.where.not(id: id).find_by(variant: self.class.key(canonical))&.canonical
    self.canonical = @resolved || canonical
  end

  # A variant may name itself to settle casing ("Salt" is "salt"); it may not
  # reach itself through another alias, which would undo that one.
  def not_its_own_canonical
    errors.add(:canonical, "would undo an existing alias") if @resolved && self.class.key(canonical) == variant
  end

  def rename_ingredients
    self.class.where.not(id: id).where("lower(canonical) = ?", variant).update_all(canonical: canonical, updated_at: Time.current)
    @renamed = Ingredient.where("lower(trim(name)) = ?", variant).where.not(name: canonical).update_all(name: canonical, updated_at: Time.current)
  end
end
