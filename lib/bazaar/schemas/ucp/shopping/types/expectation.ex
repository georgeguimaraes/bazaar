defmodule Bazaar.Schemas.Shopping.Types.Expectation do
  @moduledoc """
  Expectation

  Buyer-facing fulfillment expectation representing logical groupings of items (e.g., 'package'). Can be split, merged, or adjusted post-order to set buyer expectations for when/how items arrive.

  Generated from: expectation.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PostalAddress
  @doc "Returns the description for a field, if available."
  def field_description(:description) do
    "Human-readable delivery description (e.g., 'Arrives in 5-8 business days')."
  end

  def field_description(:destination) do
    "Delivery destination address."
  end

  def field_description(:fulfillable_on) do
    "When this expectation can be fulfilled: 'now' or ISO 8601 timestamp for future date (backorder, pre-order)."
  end

  def field_description(:id) do
    "Expectation identifier."
  end

  def field_description(:line_items) do
    "Which line items and quantities are in this expectation."
  end

  def field_description(:method_type) do
    "Delivery method type. Well-known values: `shipping`, `pickup`, `digital`; additional values MAY be used."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:description, :string)
    field(:fulfillable_on, :string)
    field(:id, :string)
    field(:line_items, {:array, :map})
    field(:method_type, :string)
    embeds_one(:destination, PostalAddress)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:description, :fulfillable_on, :id, :line_items, :method_type])
    |> cast_embed(:destination, required: true)
    |> validate_required([:id, :line_items, :method_type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
