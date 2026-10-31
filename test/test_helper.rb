ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Answers with whatever it was given, or raises it. Stands in for LlmClient.
class FakeLlm
  attr_reader :calls

  def initialize(answer) = (@answer = answer) && (@calls = 0)
  def configured? = true

  def complete_json(**)
    @calls += 1
    raise @answer if @answer.is_a?(Exception)

    @answer
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
