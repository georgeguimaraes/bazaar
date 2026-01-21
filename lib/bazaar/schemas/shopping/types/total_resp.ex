defmodule Bazaar.Schemas.Shopping.Types.TotalResp do
  @moduledoc """
  Total Response
  
  Generated from: total_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @type_values [:items_discount, :subtotal, :discount, :fulfillment, :tax, :fee, :total]
  @field_descriptions %{
    amount:
      "If type == total, sums subtotal - discount + fulfillment + tax + fee. Should be >= 0. Amount in minor (cents) currency units.",
    display_text:
      "Text to display against the amount. Should reflect appropriate method (e.g., 'Shipping', 'Delivery').",
    type: "Type of total categorization."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amount, :integer)
    field(:display_text, :string)
    field(:type, Ecto.Enum, values: @type_values)
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
