defmodule Bazaar.Plugs.UCP do
  @moduledoc """
  The UCP request pipeline in one plug: `Bazaar.Plugs.UCPHeaders` followed by
  `Bazaar.Plugs.Idempotency`.

      pipeline :ucp do
        plug :accepts, ["json"]
        plug Bazaar.Plugs.UCP
      end

  Options are handed to both plugs, so `store:`, `methods:`, `reservation_ttl:`
  and `version:` work here exactly as they do on the plugs themselves:

      plug Bazaar.Plugs.UCP, store: {Bazaar.Idempotency.Cachex, :idempotency}, version: false

  Request and response validation stay separate plugs, since they take
  per-action schema configuration.
  """

  alias Bazaar.Plugs.{Idempotency, UCPHeaders}

  @behaviour Plug

  @impl true
  def init(opts), do: %{headers: UCPHeaders.init(opts), idempotency: Idempotency.init(opts)}

  @impl true
  def call(conn, opts) do
    case UCPHeaders.call(conn, opts.headers) do
      %{halted: true} = conn -> conn
      conn -> Idempotency.call(conn, opts.idempotency)
    end
  end
end
