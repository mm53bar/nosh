namespace :images do
  desc "Generate the named image variants for recipes attached before they existed"
  task warm: :environment do
    variants = %i[ card kitchen_card kitchen_corner ]
    scope = Recipe.with_attached_image
    total = scope.count
    generated = 0
    skipped = 0

    # `preprocessed: true` only fires on attach, so anything attached before the
    # variants were declared has no rendition and pays generation cost on the
    # first request that asks for it — on one of only three Puma threads. This
    # backfills them. Sequential and nice'd on purpose: libvips on the NAS is
    # the bottleneck, and racing it with live requests is the thing we're
    # trying to avoid.
    scope.find_each.with_index(1) do |recipe, index|
      unless recipe.image.attached? && recipe.image.variable?
        skipped += 1
        next
      end

      variants.each do |variant|
        recipe.image.variant(variant).processed
        generated += 1
      end

      puts "[#{index}/#{total}] #{recipe.title}"
    rescue StandardError => e
      # One unprocessable blob shouldn't abandon the remaining recipes.
      warn "[#{index}/#{total}] FAILED #{recipe.title} (#{recipe.id}): #{e.class} #{e.message}"
      skipped += 1
    end

    puts "\n#{generated} variants processed across #{total} recipes (#{skipped} skipped)."
  end
end
