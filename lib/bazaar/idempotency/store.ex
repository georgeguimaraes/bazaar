defmodule Bazaar.Idempotency.Store do
  @moduledoc """
  Storage behaviour for `Bazaar.Plugs.Idempotency`.

  A store keeps the first response seen for an idempotency key so the plug can
  replay it. `Bazaar.Idempotency.ETS` is the bundled in-memory store; a
  deployment with more than one node wants one backed by shared storage.
  """

  @type store :: term()
  @type record :: %{fingerprint: integer(), status: pos_integer(), body: binary()}

  @callback fetch(store(), key :: String.t()) :: {:ok, record()} | :error
  @callback put(store(), key :: String.t(), record()) :: :ok
end
