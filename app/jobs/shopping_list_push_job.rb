# Publishing means one HTTP call per new item, which is a few seconds on a
# full week's list — long enough to keep out of the request.
class ShoppingListPushJob < ApplicationJob
  queue_as :default

  # A Home Assistant that is down or mid-restart should not retry forever; the
  # next publish re-diffs and picks up whatever didn't land.
  retry_on HomeAssistantTodo::Error, wait: :polynomially_longer, attempts: 3

  def perform
    result = ShoppingListPublisher.new.publish
    Rails.logger.info("[shopping list] #{result.summary}")
    result
  end
end
