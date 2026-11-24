defmodule Bazaar.Schemas.Shopping.DiscountResp.Allocation do
  @moduledoc """
  Schema

  Breakdown of how a discount amount was allocated to a specific target.

  Generated from: discount_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:amount) do
    "Amount allocated to this target in ISO 4217 minor units."
  end

  def field_description(:path) do
    "RFC 9535 JSONPath to the allocation target (e.g., '$.line_items[0]', '$.totals[?@.type == \"fulfillment\"]')."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:amount, :integer)
    field(:path, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:amount, :path]) |> validate_required([:path, :amount])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
