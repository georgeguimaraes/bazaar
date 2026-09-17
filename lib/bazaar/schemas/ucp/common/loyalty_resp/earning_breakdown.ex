defmodule Bazaar.Schemas.Common.LoyaltyResp.EarningBreakdown do
  @moduledoc """
  Schema

  Breakdown rule of the reward earnings

  Generated from: loyalty_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    amount: "Rewards earned from this rule.",
    benefit_id:
      "Optional `id` of the membership_tier_benefit that produced this rewards rule. Resolves against `membership_tier_benefit.id` within the same parent loyalty membership.",
    description:
      "A display-ready, human-readable rationale for the specific rewards (e.g. 2x on footwear).",
    id: "Unique rewards breakdown rule identifier."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amount, :integer)
    field(:benefit_id, :string)
    field(:description, :string)
    field(:id, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:amount, :benefit_id, :description, :id])
    |> validate_required([:id, :amount, :description])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
