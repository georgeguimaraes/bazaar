defmodule Bazaar.Schemas.Common.LoyaltyUpdateReq.MembershipTier do
  @moduledoc """
  Schema

  Specific achievement rank or status milestone that unlocks escalating value as a member progresses through activity or spend.

  Generated from: loyalty.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.LoyaltyUpdateReq.MembershipTierBenefit

  @field_descriptions %{
    benefits: "List of benefits associated with this tier.",
    id: "Unique identifier for the membership tier.",
    name: "The human-readable name of the tier (e.g., 'Platinum')."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:name, :string)
    embeds_many(:benefits, MembershipTierBenefit)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :name])
    |> cast_embed(:benefits, required: false)
    |> validate_required([:id, :name])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
