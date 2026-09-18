defmodule Bazaar.TestRepo do
  @moduledoc false
  use Ecto.Repo, otp_app: :bazaar, adapter: Ecto.Adapters.SQLite3
end

defmodule Bazaar.TestEctoStore do
  @moduledoc false
  use Bazaar.Store.Ecto, repo: Bazaar.TestRepo
end
