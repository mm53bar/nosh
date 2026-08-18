require "test_helper"
require "yaml"

# Solid Queue runs inside Puma (config/puma.rb), so job threads and request
# threads draw on the same primary connection pool. Sizing the pool for requests
# alone is what deadlocked verso in production.
#
# This asserts the *arithmetic*, not the symptom. The symptom is unreachable
# here: the suite is single-threaded, so it can never exhaust a pool no matter
# how badly sized it is. Nothing else in a green run would notice this
# regressing.
class ConnectionPoolSizingTest < ActiveSupport::TestCase
  # config/puma.rb: threads_count = ENV.fetch("RAILS_MAX_THREADS", N)
  def puma_threads
    source = Rails.root.join("config/puma.rb").read
    match = source.match(/RAILS_MAX_THREADS["']?,\s*(\d+)/)
    assert match, "could not read the Puma thread default out of config/puma.rb"
    Integer(match[1])
  end

  # config/queue.yml: each worker gets its own thread pool, and a job that
  # touches a model checks out a *primary* connection even though Solid Queue's
  # own tables live in the queue database.
  def solid_queue_threads
    config = YAML.load_file(Rails.root.join("config/queue.yml"), aliases: true).fetch("production")
    config.fetch("workers").sum { |worker| Integer(worker.fetch("threads", 1)) }
  end

  def production_primary_max_connections
    Integer(Rails.application.config.database_configuration
      .fetch("production").fetch("primary").fetch("max_connections"))
  end

  test "the production pool covers request threads and job threads together" do
    needed = puma_threads + solid_queue_threads

    assert_operator production_primary_max_connections, :>=, needed,
      "config/database.yml must size max_connections for #{puma_threads} Puma threads " \
      "plus #{solid_queue_threads} Solid Queue worker threads"
  end

  # Rails 8.1 renamed the key; `pool` still works but is deprecated, and mixing
  # the two raises. Cheap to state so nobody reintroduces the old spelling from
  # another app's database.yml.
  test "database.yml uses the current pool key" do
    source = Rails.root.join("config/database.yml").read

    assert_match(/^\s*max_connections:/, source)
    assert_no_match(/^\s*pool:/, source)
  end
end
