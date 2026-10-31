require "open-uri"

# A recipe found by something other than a person — today a YouTube transcript
# — waiting for a person to look at it. It is never a Recipe until someone
# accepts it, so nothing that reads recipes (the list, the JSON API, the
# Saturday slate) can pick up an unreviewed one. Automatic adding is how fish
# got into the collection before. See
# docs/adr/20261030-recipe-candidates-wait-for-review.md.
#
# The proposal is shaped like a schema.org/Recipe node, so RecipeImporter
# turns it into a recipe exactly as it would an imported page.
class RecipeCandidate < ApplicationRecord
  MAX_ATTEMPTS = 3
  MEAL_TYPES = %w[Dinner Breakfast Drink Dessert Bread Sauce Snack].freeze

  # Ingredient words that mean a dish isn't lacto-ovo vegetarian. A second
  # opinion beside the model's own answer, which is how fish got past before;
  # a false alarm here costs a glance, a miss costs a dinner.
  # Vegetarian versions ("vegetable stock", "vegan fish sauce") are struck out
  # first, so "chicken or vegetable stock" still flags the chicken.
  VEGETARIAN_VERSION = /\b(?:vegetable|veggie|vegan|vegetarian|meatless|mushroom|plant[- ]based)\s+\w+/i
  NOT_VEGETARIAN = /\b(beef|pork|bacon|ham|lard|chicken|turkey|duck|lamb|veal|sausages?|chorizo|pancetta|prosciutto|salami|pepperoni|gelatine?|fish|anchov(?:y|ies)|worcestershire|salmon|tuna|cod|basa|tilapia|halibut|shrimps?|prawns?|crab|lobster|scallops?|clams?|mussels?|oyster sauce|dashi|bonito|broth|stock)\b/i

  belongs_to :recipe, optional: true

  enum :status, { queued: "queued", ready: "ready", failed: "failed", accepted: "accepted", discarded: "discarded" },
       validate: true

  validates :origin, :source_url, presence: true
  validates :source_url, uniqueness: true, format: { with: %r{\Ahttps?://\S+\z}i }

  scope :awaiting_review, -> { where(status: %w[ready failed]).order(:created_at) }

  def awaiting_review? = ready? || failed?

  # One extraction per call, so each transcript costs one completion when it
  # works. An outage (LlmClient::Unavailable) raises without spending an
  # attempt; an unusable answer spends one, and the last one marks it failed.
  def extract!(llm)
    answer = llm.complete_json(system: PROMPT, user: extraction_input, timeout: 180)
    if usable?(answer)
      update!(proposal: answer, status: :ready, error: nil, attempts: attempts + 1)
    else
      self.attempts += 1
      self.error = "The model's answer had no ingredients or steps"
      self.status = :failed if attempts >= MAX_ATTEMPTS
      save!
    end
  end

  def recipe? = proposal.present? && proposal["is_recipe"] != false

  def skip_reason = proposal&.dig("skip_reason").presence

  # Ingredient lines that suggest meat or fish: the model's own list, plus any
  # line the word check catches.
  def meat_warnings
    return [] unless proposal

    flagged = Array(proposal["not_vegetarian"]).map(&:to_s)
    flagged += RecipeSource.ingredient_lines(proposal).select { |line| line.gsub(VEGETARIAN_VERSION, "").match?(NOT_VEGETARIAN) }
    flagged.compact_blank.uniq
  end

  def build_recipe
    recipe = RecipeImporter.new(source_url).build(proposal || {})
    recipe.title = title if recipe.title.blank?
    recipe
  end

  # Saves the recipe the reviewer submitted and links it, or returns false with
  # the recipe's errors on it. Only once: a resubmitted form must not add a
  # second copy.
  def accept(recipe)
    return false unless awaiting_review?

    transaction do
      raise ActiveRecord::Rollback unless recipe.save

      update!(status: :accepted, recipe: recipe)
    end
    return false unless accepted?

    attach_image(recipe) unless recipe.image.attached?
    true
  end

  private

  PROMPT = <<~PROMPT.freeze
    You turn a cooking video's transcript into a recipe, as one JSON object shaped like a
    schema.org Recipe. Reply with the JSON object only.

    Rules:
    - If the video is not one specific cookable dish (an equipment review, food science, a
      vlog, a round-up of many dishes, a product promotion), set "is_recipe": false, give a
      short "skip_reason", and leave the other fields empty.
    - "recipeIngredient" is a list of ingredient lines as a cookbook writes them: amount,
      unit, ingredient, then any prep after a comma ("1 1/2 cups cooked chickpeas, drained").
      Use fractions, not decimals. Leave the amount out rather than guess one.
    - "recipeInstructions" is a list of short, clear steps. Leave out sponsor reads, calls
      to subscribe, and chatter.
    - "recipeCategory" is one of: #{MEAL_TYPES.join(", ")}.
    - "prepTime" and "totalTime" are ISO 8601 durations ("PT20M"), or null when the video
      doesn't say.
    - "keywords" is a few short lowercase tags: dish type, main ingredient, cuisine.
    - The household is lacto-ovo vegetarian. "vegetarian" is false if any ingredient is
      meat, poultry, fish, seafood, or made from them (fish sauce, chicken stock, gelatin,
      Worcestershire sauce). List those ingredient lines in "not_vegetarian".

    Example of the shape:
    {
      "is_recipe": true,
      "skip_reason": null,
      "name": "Crispy Smashed Chickpea Tacos",
      "description": "Pan-crisped chickpeas with a lime crema in warm tortillas.",
      "recipeYield": "4",
      "prepTime": "PT10M",
      "totalTime": "PT25M",
      "recipeCuisine": "Mexican",
      "recipeCategory": "Dinner",
      "keywords": ["tacos", "chickpeas", "mexican"],
      "recipeIngredient": ["2 cans chickpeas, drained", "1 tbsp olive oil", "8 small corn tortillas"],
      "recipeInstructions": ["Smash the chickpeas with a fork.", "Fry in the oil until crisp."],
      "vegetarian": true,
      "not_vegetarian": []
    }
  PROMPT

  def extraction_input
    [ "Video title: #{title}", "Video: #{source_url}", "", source_text.to_s.truncate(40_000) ].join("\n")
  end

  def usable?(answer)
    return false unless answer.is_a?(Hash)
    return true if answer["is_recipe"] == false

    RecipeSource.ingredient_lines(answer).any? && Array(answer["recipeInstructions"]).any?
  end

  def attach_image(recipe)
    return if image_url.blank?

    downloaded = URI.open(image_url, "User-Agent" => "Mozilla/5.0 (compatible; nosh-importer)", read_timeout: 15)
    recipe.image.attach(io: downloaded, filename: "#{recipe.title.parameterize}.jpg")
  rescue StandardError => e
    Rails.logger.warn("RecipeCandidate ##{id}: image fetch failed: #{e.class}: #{e.message}")
  end
end
