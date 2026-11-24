defmodule Bazaar.Schemas.UcpUpdateReq.ResponseCheckoutSchema do
  @moduledoc """
  UCP Checkout Response Schema Update Request

  UCP metadata for checkout responses.

  Generated from: ucp.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @status_values [:success, :error]
  @doc "Returns the description for a field, if available."
  def field_description(:capabilities) do
    "Capability registry keyed by reverse-domain name."
  end

  def field_description(:payment_handlers) do
    "Payment handler registry keyed by reverse-domain name."
  end

  def field_description(:services) do
    "Service registry keyed by reverse-domain name."
  end

  def field_description(:status) do
    "Application-level status of the UCP operation."
  end

  def field_description(:version) do
    "Version identifier in YYYY-MM-DD format."
  end

  def field_description(field) when is_atom(field) do
    nil
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
    |> validate_required([:version, :payment_handlers])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
