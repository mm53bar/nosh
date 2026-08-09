class Recipe < ApplicationRecord
  has_one_attached :image

  has_many :ingredients, -> { order(:position) }, dependent: :destroy, inverse_of: :recipe
  has_many :steps, -> { order(:position) }, dependent: :destroy, inverse_of: :recipe
  has_many :recipe_tags, dependent: :destroy
  has_many :tags, through: :recipe_tags
  has_many :meal_plan_entries, dependent: :destroy

  accepts_nested_attributes_for :ingredients, :steps, allow_destroy: true

  validates :title, presence: true
  validates :rating, inclusion: { in: 1..5 }, allow_nil: true
  # Rejects javascript:/data: URLs, etc. — source_url is rendered as a link_to
  # href, so an unrestricted scheme would be a stored-XSS vector.
  validates :source_url, format: { with: %r{\Ahttps?://\S+\z}i, message: "must be a valid http:// or https:// URL" }, allow_blank: true

  scope :planned_since, ->(date) { joins(:meal_plan_entries).where(meal_plan_entries: { date: date.. }).distinct }

  # Convenience accessor for the JSON API: accepts/returns an array of tag
  # name strings instead of Tag records, resolving or creating Tags as needed.
  def tag_names=(names)
    self.tags = Array(names).map { |name| Tag.find_or_create_by(name: name.to_s.strip) }
  end

  def tag_names
    tags.map(&:name)
  end

  # Comma-separated string convenience for the HTML form, which has no good
  # widget for an array param — delegates to tag_names= once split.
  def tag_names_text=(text)
    self.tag_names = text.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def tag_names_text
    tag_names.join(", ")
  end
end
