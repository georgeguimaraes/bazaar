defmodule Bazaar.Schemas.Common.LoyaltyCreateReq.RewardCurrency do
  @moduledoc """
  Schema

  The currency of the loyalty reward.

  Generated from: loyalty.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    code: "Business-specific representation of the currency (e.g. 'LST').",
    decimal_places:
      "The position of a digit to the right of a decimal point. Applies to all amount related fields for rewards.",
    name: "Human-readable name of the currency (e.g. 'LoyaltyStars')."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:code, :string)
    field(:decimal_places, :integer)
    field(:name, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:code, :decimal_places, :name]) |> validate_required([:name, :code])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
