module Kitchen
  # "What are we cooking?" — this week's plan, or suggestions when there isn't
  # one. An empty week is the normal case rather than an error state: the
  # household plans in bursts, so the screen has to be useful in between.
  class MealsController < BaseController
    # Roughly what fits 1280×800 without scrolling.
    SUGGESTION_LIMIT = 6

    def index
      @start_date = Date.current.beginning_of_week
      @end_date = @start_date + 6.days
      @entries = MealPlanEntry.where(date: @start_date..@end_date)
        .includes(recipe: { image_attachment: :blob })
        .order(:date)

      @suggestions = suggested_recipes if @entries.empty?
    end

    private

      # Deliberately deterministic — the kiosk reloads on its own schedule, and
      # a screen that reshuffles itself mid-decision is worse than a stale one.
      # Rated dinners first (there are very few, so they're a real signal),
      # then never-made ones, newest addition first. No Random, no sample.
      def suggested_recipes
        Recipe.where(meal_type: "Dinner")
          .includes(image_attachment: :blob)
          .order(Arel.sql("rating IS NULL, rating DESC"))
          .order(Arel.sql("last_made_on IS NOT NULL, last_made_on ASC"))
          .order(created_at: :desc)
          .limit(SUGGESTION_LIMIT)
      end
  end
end
