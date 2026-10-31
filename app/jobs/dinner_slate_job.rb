# Saturday morning: next week's dinner ideas, for the Meal Plan page. One model
# call when it works. An outage retries through the morning, then leaves a
# failed slate so the banner says so. Not configured (no LLM) → does nothing.
class DinnerSlateJob < ApplicationJob
  queue_as :default
  limits_concurrency key: "dinner_slate", duration: 10.minutes, on_conflict: :discard

  retry_on LlmClient::Unavailable, wait: 30.minutes, attempts: 4 do |job, error|
    DinnerSlate.create!(week_start: job.week_start, status: :failed, error: "The model was unavailable: #{error.message}")
  end

  def perform(llm: LlmClient.from_env)
    return unless llm.configured?
    return if DinnerSlate.current(week_start)&.ready?

    DinnerSlate.suggest(week_start, llm: llm).save!
  end

  def week_start = Date.current.next_week
end
