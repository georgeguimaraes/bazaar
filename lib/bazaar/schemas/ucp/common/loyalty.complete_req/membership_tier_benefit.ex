defmodule Bazaar.Schemas.Common.LoyaltyCompleteReq.MembershipTierBenefit do
  @moduledoc """
  Schema

  Benefits associated with a membership tier.

  Generated from: loyalty.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    description:
      "A display-ready, human-readable explanation of this benefit (e.g. 'Early access to sales').",
    id: "Unique identifier for the tier benefit."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:description, :string)
    field(:id, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:description, :id]) |> validate_required([:id, :description])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
