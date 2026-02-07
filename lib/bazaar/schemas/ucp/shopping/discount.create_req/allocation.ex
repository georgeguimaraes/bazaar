defmodule Bazaar.Schemas.Shopping.DiscountCreateReq.Allocation do
  @moduledoc """
  Schema

  Breakdown of how a discount amount was allocated to a specific target.

  Generated from: discount.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    amount: "Amount allocated to this target in minor (cents) currency units.",
    path: "JSONPath to the allocation target (e.g., '$.line_items[0]', '$.totals.shipping')."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
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
