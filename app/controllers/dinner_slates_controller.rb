# "Suggest again", and "Try again" after a slate couldn't be made. The work is
# DinnerSlateJob's; the Meal Plan page refreshes when it's done.
class DinnerSlatesController < ApplicationController
  def create
    week_start = Date.parse(params.require(:week_start)).beginning_of_week
    DinnerSlateJob.perform_later(week_start: week_start, again: true)

    redirect_to meal_plan_entries_path(start: week_start), notice: "Finding dinner ideas. They'll appear here in a moment."
  end
end
