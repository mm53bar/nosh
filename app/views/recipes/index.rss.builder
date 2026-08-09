xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "nosh — Recipes"
    xml.link recipes_url
    xml.description "Recently added recipes"
    xml.language "en"

    @recipes.each do |recipe|
      xml.item do
        xml.title recipe.title
        xml.link recipe_url(recipe)
        xml.guid recipe_url(recipe)
        xml.pubDate recipe.created_at.rfc822
        xml.description recipe.description if recipe.description.present?
      end
    end
  end
end
