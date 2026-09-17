defmodule Bazaar.Schemas.Common.Types.Signals do
  @moduledoc """
  Signals

  Environment data provided by the platform to support authorization and abuse prevention. Values MUST NOT be buyer-asserted claims — platforms provide signals based on direct observation or independently verifiable third-party attestations. All signal keys MUST use reverse-domain naming to ensure provenance and prevent collisions when multiple extensions contribute to the shared namespace.

  Generated from: signals.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    "dev.ucp.buyer_ip": "Client's IP address (IPv4 or IPv6).",
    "dev.ucp.user_agent": "Client's HTTP User-Agent header or equivalent."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:"dev.ucp.buyer_ip", :string)
    field(:"dev.ucp.user_agent", :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:"dev.ucp.buyer_ip", :"dev.ucp.user_agent"])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
