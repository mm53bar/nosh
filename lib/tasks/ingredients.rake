namespace :ingredients do
  desc "Report ingredient names that aren't shopping labels (see IngredientNameLinter)"
  task lint: :environment do
    findings = IngredientNameLinter.call
    total = Ingredient.count

    if findings.empty?
      puts "No findings across #{total} ingredients."
      next
    end

    flagged = findings.map { |finding| finding.ingredient.id }.uniq.size
    puts "#{flagged} of #{total} ingredients flagged (#{findings.size} findings)\n\n"

    findings.group_by(&:rule).each do |rule, rule_findings|
      puts "#{rule} — #{IngredientNameLinter::RULES.dig(rule, :description)} (#{rule_findings.size})"
      rule_findings.sort_by { |finding| finding.name }.each do |finding|
        puts "  #{finding.name}"
        puts "    #{finding.detail}  ·  #{finding.recipe_title} (recipe #{finding.ingredient.recipe_id})"
      end
      puts
    end
  end
end
