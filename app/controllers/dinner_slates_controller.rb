# "Suggest again", and "Try again" after a slate couldn't be made. Waits for
# the model in the request (a few seconds to a minute) so the page that comes
# back has the new ideas on it.
class DinnerSlatesController < ApplicationController
  def create
    week_start = Date.parse(params.require(:week_start)).beginning_of_week
    current = DinnerSlate.current(week_start)
    llm = LlmClient.from_env
    slate = current&.ready? ? current.suggest_again(llm: llm) : DinnerSlate.suggest(week_start, llm: llm).tap(&:save!)

    redirect_to meal_plan_entries_path(start: week_start),
                **(slate.ready? ? { notice: "New ideas for the week." } : { alert: "Couldn't suggest new dinners: #{slate.error}." })
  rescue LlmClient::Unavailable
    redirect_to meal_plan_entries_path(start: week_start), alert: "The model isn't answering right now. Try again in a few minutes."
  end
end
