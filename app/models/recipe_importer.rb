require "open-uri"
require "json"

# Creates a Recipe from a source page's embedded schema.org/Recipe JSON-LD —
# the structured-data block most recipe sites (and nosh's own recipe pages)
# already emit for Google/Pinterest/recipe-clipper tools. This is the "handy
# way to add a recipe" replacing a manual-entry button: paste a URL, nosh
# reads the same structured data those tools already read.
#
# hRecipe (the older microformat) is deliberately not supported — it's been
# dead in the wild for over a decade; every modern recipe site uses JSON-LD.
class RecipeImporter
  Result = Struct.new(:recipe, :error) do
    def success? = error.nil?
  end

  # html: lets tests inject a canned page body instead of hitting the network
  # — the same "inject a fake at the real dependency" pattern used elsewhere
  # in this app family (e.g. blip's ImapIntakeJob) rather than a mocking library.
  def initialize(url, html: nil)
    @url = url
    @html_override = html
  end

  def call
    uri = parse_uri(@url)
    return Result.new(nil, "Invalid URL — must be http:// or https://") unless uri

    html = @html_override || fetch(uri)
    return Result.new(nil, "Couldn't fetch that URL") unless html

    data = RecipeSource.extract(html)
    return Result.new(nil, "No recipe data (schema.org/Recipe JSON-LD) found on that page") unless data

    recipe = build(data)
    if recipe.save
      RecipeSource.new(recipe).capture!(html)
      attach_image(recipe, data["image"])
      Result.new(recipe, nil)
    else
      Result.new(nil, recipe.errors.full_messages.to_sentence)
    end
  end

  # An unsaved recipe from a schema.org/Recipe node. Also how a RecipeCandidate's
  # proposal, which is shaped like one, becomes a recipe to review.
  def build(data)
    recipe = Recipe.new(
      title: plain_text(data["name"]),
      description: plain_text(data["description"]),
      source_url: @url,
      servings: extract_yield(data["recipeYield"]),
      cuisine: plain_text(Array(data["recipeCuisine"]).first),
      meal_type: plain_text(Array(data["recipeCategory"]).first),
      prep_time_minutes: iso8601_minutes(data["prepTime"]),
      total_time_minutes: iso8601_minutes(data["totalTime"])
    )
    recipe.tag_names = extract_keywords(data["keywords"]).map { |keyword| plain_text(keyword) }.compact_blank

    RecipeSource.ingredient_lines(data).each_with_index do |line, index|
      recipe.ingredients.build(parse_ingredient_line(line).merge(original_text: line, position: index))
    end

    extract_instructions(data["recipeInstructions"]).filter_map { |text| plain_text(text) }.each_with_index do |text, index|
      recipe.steps.build(instruction: text, position: index)
    end

    recipe
  end

  private

  def parse_uri(url)
    uri = URI.parse(url.to_s)
    uri if %w[http https].include?(uri.scheme)
  rescue URI::InvalidURIError
    nil
  end

  def fetch(uri)
    URI.open(uri, "User-Agent" => "Mozilla/5.0 (compatible; nosh-importer)", redirect: true, read_timeout: 15).read
  rescue StandardError
    nil
  end

  def extract_yield(recipe_yield)
    Array(recipe_yield).first.to_s[/\d+/]&.to_i
  end

  def iso8601_minutes(duration)
    return nil if duration.blank?

    (ActiveSupport::Duration.parse(duration).to_i / 60)
  rescue ActiveSupport::Duration::ISO8601Parser::ParsingError
    nil
  end

  def extract_keywords(keywords)
    return [] if keywords.blank?

    keywords.is_a?(Array) ? keywords : keywords.to_s.split(",").map(&:strip)
  end

  def extract_instructions(instructions)
    case instructions
    when String
      instructions.split(/\r?\n+/).map(&:strip).reject(&:blank?)
    when Array
      instructions.flat_map do |step|
        case step
        when String then step
        when Hash
          step["@type"] == "HowToSection" ? Array(step["itemListElement"]).map { |s| s["text"] || s["name"] } : (step["text"] || step["name"])
        end
      end.compact
    else
      []
    end
  end

  def parse_ingredient_line(line) = IngredientLine.parse(line).to_attributes

  def plain_text(value) = RecipeSource.plain_text(value)

  def attach_image(recipe, image)
    url = Array(image).first
    url = url["url"] if url.is_a?(Hash)
    return if url.blank?

    uri = parse_uri(url)
    return unless uri

    downloaded = URI.open(uri, "User-Agent" => "Mozilla/5.0 (compatible; nosh-importer)", redirect: true, read_timeout: 15)
    recipe.image.attach(io: downloaded, filename: File.basename(uri.path.presence || "image.jpg"))
  rescue StandardError
    nil
  end
end
