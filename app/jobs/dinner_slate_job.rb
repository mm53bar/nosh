# A week's dinner ideas: next week's on Saturday morning, or any week's when
# someone presses "Suggest again" / "Try again". Never in the request — a model
# call can outlast the proxy's timeout. The Meal Plan page refreshes itself
# when this finishes. An outage retries; when the retries run out, the failure
# is recorded where the page and banner show it. Not configured → does nothing.
class DinnerSlateJob < ApplicationJob
  queue_as :default
  limits_concurrency key: "dinner_slate", duration: 10.minutes, on_conflict: :discard

  retry_on LlmClient::Unavailable, wait: 30.seconds, attempts: 3 do |job, error|
    week_start = job.arguments.first&.dig(:week_start) || Date.current.next_week
    DinnerSlate.record_failure(week_start, "The model was unavailable (#{error.message})")
    Turbo::StreamsChannel.broadcast_refresh_to("dinner_slates")
  end

  def perform(week_start: nil, again: false, llm: LlmClient.from_env)
    return unless llm.configured?

    week_start ||= Date.current.next_week
    current = DinnerSlate.current(week_start)
    if again && current&.ready?
      slate = current.suggest_again(llm: llm)
      DinnerSlate.record_failure(week_start, slate.error) if slate.failed?
    elsif !current&.ready?
      DinnerSlate.suggest(week_start, llm: llm).save!
    end
    Turbo::StreamsChannel.broadcast_refresh_to("dinner_slates")
  end
end
