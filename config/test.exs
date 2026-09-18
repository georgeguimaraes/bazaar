import Config

# The Ecto store's tests run on SQLite; the repo lives in test/support.
config :bazaar, Bazaar.TestRepo,
  database: Path.join(__DIR__, "../tmp/bazaar_test.db"),
  pool_size: 1,
  log: false

config :bazaar, ecto_repos: [Bazaar.TestRepo]
