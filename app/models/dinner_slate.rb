# A week's dinner ideas: about eight recipes from the collection, chosen by an
# LLM, for someone to put on nights on the Meal Plan page. Ruby decides what may
# be suggested (dinners not cooked or planned lately); the model only chooses
# among them, and anything it names outside that list is dropped. A slate it
# couldn't fill is kept as failed, so the banner says so rather than showing an
# empty week. See docs/adr/20261030-dinner-ideas-on-the-meal-plan.md.
#
# "Suggest again" makes a new slate for the same week, keeping the ideas
# already on the plan; the newest slate for a week is the one shown.
class DinnerSlate < ApplicationRecord
  SIZE = 8
  POOL_CAP = 120
  RECENT = 14.days

  Idea = Struct.new(:recipe, :complexity, :why)

  enum :status, { ready: "ready", failed: "failed" }, validate: true

  validates :week_start, presence: true

  def self.current(week_start) = where(week_start: week_start).order(:created_at, :id).last

  # The newest slate for a week that hasn't ended, when it still needs saying:
  # ideas nobody has looked at yet, or a slate that couldn't be made.
  def self.to_announce
    slate = where(week_start: Date.current.beginning_of_week..).order(:created_at, :id).last
    slate if slate && (slate.failed? || slate.seen_at.nil?)
  end

  # An unsaved slate, ready or failed: the caller decides whether a failure is
  # worth keeping. Raises LlmClient::Unavailable on an outage, so a caller can
  # retry or say so.
  def self.suggest(week_start, llm:, keep: [], excluding: [])
    kept = Array(keep)
    wanted = SIZE - kept.size
    return new(week_start: week_start, status: :ready, ideas: kept) if wanted <= 0

    candidates = pool(week_start, excluding: excluding + kept.map { |idea| idea["recipe_id"] }).to_a.shuffle.first(POOL_CAP)
    return new(week_start: week_start, status: :failed, error: "No dinners left to suggest") if candidates.empty?

    enough = [ (wanted / 2.0).ceil, candidates.size ].min
    picks = 2.times.lazy.map { choose(llm, candidates, wanted, kept) }.find { |ideas| ideas.size >= enough }
    if picks
      new(week_start: week_start, status: :ready, ideas: kept + picks.first(wanted))
    else
      new(week_start: week_start, status: :failed, error: "The model didn't pick enough dinners from the collection")
    end
  end

  # Dinners that may be suggested: not cooked lately, not already planned
  # lately or for this week, and not a breakfast, dessert, drink or the like.
  def self.pool(week_start, excluding: [])
    planned = MealPlanEntry.where(date: (Date.current - RECENT)..(week_start + 6)).where.not(recipe_id: nil).select(:recipe_id)
    Recipe.includes(:tags, :ingredients)
      .where("meal_type IS NULL OR meal_type = '' OR lower(meal_type) LIKE '%dinner%' OR lower(meal_type) LIKE '%main%'")
      .where("last_made_on IS NULL OR last_made_on < ?", Date.current - RECENT)
      .where.not(id: planned).where.not(id: excluding)
  end

  def self.choose(llm, candidates, wanted, kept)
    answer = llm.complete_json(system: system_prompt, user: request(candidates, wanted, kept), timeout: 120)
    allowed = candidates.index_by(&:id)
    Array(answer.is_a?(Hash) ? answer["ideas"] : nil).filter_map do |idea|
      next unless idea.is_a?(Hash) && (recipe = allowed[idea["id"].to_s.to_i])

      { "recipe_id" => recipe.id, "complexity" => idea["complexity"].to_s.presence_in(%w[quick medium involved]),
        "why" => idea["why"].to_s.squish.presence }
    end.uniq { |idea| idea["recipe_id"] }
  end

  def self.request(candidates, wanted, kept)
    cuisines = Recipe.where.not(cuisine: [ nil, "" ]).group(:cuisine).order(count_all: :desc).limit(12).count
    kept_titles = Recipe.where(id: kept.map { |idea| idea["recipe_id"] }).pluck(:title)

    [ "Pick #{wanted} dinners.",
      ("Already chosen for this week, so complement them: #{kept_titles.join("; ")}." if kept_titles.any?),
      "Cuisines across the whole collection: #{cuisines.map { |name, count| "#{name} #{count}" }.join(", ")}.",
      "", "Dinners to choose from (id | title | cuisine | time | rating | tags | main ingredients):",
      *candidates.map { |recipe| line(recipe) } ].compact.join("\n")
  end

  def self.line(recipe)
    [ recipe.id, recipe.title, recipe.cuisine.presence || "?",
      (recipe.total_time_minutes || recipe.prep_time_minutes)&.then { "#{_1} min" } || "? min",
      recipe.rating ? "#{recipe.rating}/5" : "unrated",
      recipe.tags.map(&:name).first(4).join(", "),
      recipe.ingredients.map(&:name).first(8).join(", ") ].join(" | ")
  end

  PROMPT = <<~PROMPT.freeze
    You plan a week of dinners for a household, choosing only from their own recipe
    collection, listed by id.

    - The household is strictly lacto-ovo vegetarian: no meat, poultry, fish or seafood,
      nor anything made from them. Skip any recipe that isn't.
    - The cook's energy varies through the week. Include several quick weeknight dinners
      (about 30 minutes, few steps) and a couple of more involved ones.
    - Favour dinners that share main ingredients, so one shop covers the week with little
      waste.
    - Keep the cuisines varied, and lean toward ones the collection has fewer of.
    - Give each a short, specific reason ("uses the rest of the cilantro from the tacos").

    Reply with one JSON object only, in this shape:
    {"ideas": [{"id": 12, "complexity": "quick", "why": "Shares chickpeas and cilantro with the curry."}]}
    "complexity" is one of quick, medium, involved.
  PROMPT
  # The household's own likes and dislikes come from the environment, since
  # the repo is public.
  def self.system_prompt
    notes = ENV["DINNER_SLATE_NOTES"].to_s.strip
    notes.empty? ? PROMPT : "#{PROMPT}\nAbout this household:\n#{notes}\n"
  end
  private_class_method :choose, :request, :line, :system_prompt

  # The ideas with their recipes, skipping any recipe deleted since.
  def suggestions
    recipes = Recipe.where(id: ideas.map { |idea| idea["recipe_id"] }).includes(image_attachment: :blob).index_by(&:id)
    ideas.filter_map do |idea|
      recipe = recipes[idea["recipe_id"]]
      Idea.new(recipe, idea["complexity"], idea["why"]) if recipe
    end
  end

  # A new slate for the same week: ideas already on the plan stay, the rest
  # are replaced, and none of this slate's ideas come back. Saved only if it
  # worked, so a failed retry leaves this one showing.
  def suggest_again(llm:)
    planned = MealPlanEntry.where(date: week_start..(week_start + 6)).pluck(:recipe_id)
    self.class.suggest(week_start, llm: llm, keep: ideas.select { |idea| planned.include?(idea["recipe_id"]) },
                                   excluding: ideas.map { |idea| idea["recipe_id"] }).tap { |slate| slate.save! if slate.ready? }
  end

  def seen! = seen_at || update!(seen_at: Time.current)
end
