defmodule Bazaar.Schemas.UcpCompleteReq.Success do
  @moduledoc """
  Schema

  UCP metadata with status 'success'. Use for response branches that carry the expected payload.

  Generated from: ucp.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @status_values [:success]
  @field_descriptions %{
    capabilities: "Capability registry keyed by reverse-domain name.",
    payment_handlers: "Payment handler registry keyed by reverse-domain name.",
    services: "Service registry keyed by reverse-domain name.",
    status: "Application-level status of the UCP operation.",
    version: "Version identifier in YYYY-MM-DD format."
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
    field(:status, Ecto.Enum, values: @status_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:capabilities, :payment_handlers, :services, :version, :status])
    |> validate_required([:version, :status])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
