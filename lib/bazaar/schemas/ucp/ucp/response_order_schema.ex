defmodule Bazaar.Schemas.Ucp.ResponseOrderSchema do
  @moduledoc """
  UCP Order Response Schema

  UCP metadata for order responses. No payment handlers needed post-purchase.

  Generated from: ucp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    capabilities: "Capability registry keyed by reverse-domain name.",
    payment_handlers: "Payment handler registry keyed by reverse-domain name.",
    services: "Service registry keyed by reverse-domain name.",
    version: "UCP version in YYYY-MM-DD format."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:capabilities, :map)
    field(:payment_handlers, :map)
    field(:services, :map)
    field(:version, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:capabilities, :payment_handlers, :services, :version])
    |> validate_required([:version])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
