defmodule Bazaar.Idempotency.Store do
  @moduledoc """
  Storage behaviour for `Bazaar.Plugs.Idempotency`.

  A key goes through two states. `reserve/3` claims it atomically before the
  action runs, so a concurrent duplicate is refused instead of executed twice.
  `put/3` then records the response for replay, or `release/2` frees the key
  when the response was not worth keeping (a 5xx).

  `Bazaar.Idempotency.ETS` is the bundled in-memory store; a deployment with
  more than one node wants one backed by shared storage.
  """

  @type store :: term()
  @type fingerprint :: integer()
  @type reservation :: %{fingerprint: fingerprint(), reserved_at: integer()}
  @type response :: %{fingerprint: fingerprint(), status: pos_integer(), body: binary()}

  @doc "Returns the reservation or recorded response for a key."
  @callback fetch(store(), key :: String.t()) :: {:ok, reservation() | response()} | :error

  @doc "Claims a key. Fails when the key is already reserved or recorded."
  @callback reserve(store(), key :: String.t(), reservation()) :: :ok | {:error, :taken}

  @doc "Records the response for a key, replacing its reservation."
  @callback put(store(), key :: String.t(), response()) :: :ok

  @doc "Frees a key so a later request can claim it."
  @callback release(store(), key :: String.t()) :: :ok
end
