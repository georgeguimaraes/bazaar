defmodule Bazaar.Schemas.Common.Types.TotalResp do
  @moduledoc """
  Total Response

  A cost breakdown entry with a category, amount, and optional display text.

  Generated from: total_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    amount:
      "Monetary amount in the currency's minor unit as defined by ISO 4217. Refer to the currency's exponent to determine minor-to-major ratio (e.g., 2 for USD, 0 for JPY, 3 for KWD). May be negative — the sign is intrinsic to the value (e.g., discounts are negative, charges are positive).",
    display_text:
      "Text to display against the amount. Should reflect appropriate method (e.g., 'Shipping', 'Delivery').",
    type:
      "Cost category. Well-known values: subtotal, items_discount, discount, fulfillment, tax, fee, total. Businesses MAY use additional values."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amount, :integer)
    field(:display_text, :string)
    field(:type, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:amount, :display_text, :type]) |> validate_required([:type, :amount])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
