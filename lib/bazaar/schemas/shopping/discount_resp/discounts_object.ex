defmodule Bazaar.Schemas.Shopping.DiscountResp.DiscountsObject do
  @moduledoc """
  Schema

  Discount codes input and applied discounts output.

  Generated from: discount_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.DiscountResp.AppliedDiscount

  @field_descriptions %{
    applied: "Discounts successfully applied (code-based and automatic).",
    codes:
      "Discount codes to apply. Case-insensitive. Replaces previously submitted codes. Send empty array to clear."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:codes, {:array, :map})
    embeds_many(:applied, AppliedDiscount)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:codes]) |> cast_embed(:applied, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
