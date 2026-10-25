require "zlib"

# The page a recipe came from, kept so that a parser change can be re-run
# against what the site actually said rather than re-fetching it — sites change
# and pages disappear. The whole page is stored gzipped on the recipe; the
# schema.org/Recipe node found in it is kept as `source_data` for quick reading.
# See docs/adr/20261025-recipes-keep-their-source-page.md.
class RecipeSource
  Result = Struct.new(:found, :matched, :ingredients, keyword_init: true)

  # JSON-LD can be one object, an array of them, or an object with an "@graph"
  # array, and "@type" can be a string or an array of strings.
  def self.extract(html)
    html.to_s.scan(%r{<script[^>]+type=["']application/ld\+json["'][^>]*>(.*?)</script>}im).each do |(block)|
      parsed = JSON.parse(block)
      nodes = parsed.is_a?(Array) ? parsed : [ parsed ]
      candidates = nodes.grep(Hash).flat_map { |node| node["@graph"] || [ node ] }
      recipe_node = candidates.grep(Hash).find { |node| Array(node["@type"]).include?("Recipe") }
      return recipe_node if recipe_node
    rescue JSON::ParserError
      next
    end
    nil
  end

  # Sites put HTML inside JSON-LD strings: entities and sometimes tags.
  def self.plain_text(value)
    return nil if value.nil?

    Nokogiri::HTML5.fragment(value.to_s).text.squish.presence
  end

  def self.ingredient_lines(data) = Array(data&.dig("recipeIngredient")).filter_map { |line| plain_text(line) }

  def initialize(recipe)
    @recipe = recipe
  end

  # `lines` are the ingredient lines as the source wrote them, for a page whose
  # JSON-LD leaves them out (Chef's Plate renders them as page text). The
  # caller read them off the page; nosh doesn't scrape site by site.
  def capture!(html, lines: nil, fetched_at: Time.current)
    data = self.class.extract(html)
    if lines.present? && self.class.ingredient_lines(data).empty?
      data = (data || {}).merge("recipeIngredient" => lines, "nosh:ingredientLinesFrom" => "page text")
    end
    @recipe.source_page.attach(io: StringIO.new(Zlib.gzip(html.to_s)), filename: "recipe-#{@recipe.id}.html.gz",
                               content_type: "application/gzip", identify: false)
    @recipe.update!(source_data: data, source_fetched_at: fetched_at)
    matched = fill_original_text(self.class.ingredient_lines(data))
    Result.new(found: data.present?, matched: matched, ingredients: @recipe.ingredients.size)
  end

  def page = (Zlib.gunzip(@recipe.source_page.download) if @recipe.source_page.attached?)

  private

  # Pairs each ingredient with the source line it came from, in order. Names
  # have been split, aliased and hand-edited since import, so a strict pass
  # pairs a line whose words include the ingredient's name, or that parses and
  # aliases to it. A loose pass then pairs what's left with a line whose parsed
  # name is part of the ingredient's ("Basil" for "fresh basil"); running it
  # second keeps it from taking a line a strict match needed. An ingredient no
  # line accounts for is left blank rather than given a guess.
  def fill_original_text(lines)
    return 0 if lines.empty?

    used = Array.new(lines.size, false)
    open = @recipe.ingredients.reload.select { |ingredient| ingredient.original_text.blank? }
    %i[strict? loose?].sum do |test|
      cursor = 0
      paired = open.select do |ingredient|
        index = (cursor...lines.size).find { |i| !used[i] && send(test, ingredient, lines[i]) } ||
                (0...cursor).find { |i| !used[i] && send(test, ingredient, lines[i]) }
        next false unless index

        used[index] = true
        cursor = index + 1
        ingredient.update_column(:original_text, lines[index])
      end
      open -= paired
      paired.size
    end
  end

  def strict?(ingredient, line)
    name = words(ingredient.name)
    return false if name.empty?

    words(aliased_name(line)) == name || (name - words(line)).empty?
  end

  def loose?(ingredient, line)
    parsed = words(aliased_name(line))
    parsed.any? && (parsed - words(ingredient.name)).empty?
  end

  def aliased_name(line)
    parsed = IngredientLine.parse(line).name
    IngredientAlias.canonical_for(parsed) || parsed
  end

  def words(text) = text.to_s.downcase.tr("-", " ").scan(/[a-z0-9']+/).map { |word| StapleMatcher.singular(word) }
end
