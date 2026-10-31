# The household's own preferences, edited in the app rather than in the repo
# (which is public) or the deployment (which only the operator can reach).
# One row: go through Setting.current. Named columns, not a key/value store.
# See docs/adr/20261031-household-settings-in-the-database.md.
class Setting < ApplicationRecord
  normalizes :dinner_slate_notes, with: ->(notes) { notes.strip.presence }

  def self.current = first_or_create!
end
