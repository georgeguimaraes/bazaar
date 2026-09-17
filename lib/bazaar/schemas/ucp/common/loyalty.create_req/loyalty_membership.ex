defmodule Bazaar.Schemas.Common.LoyaltyCreateReq.LoyaltyMembership do
  @moduledoc """
  Schema

  Loyalty membership the business has accepted for the eligibility claim represented by the parent map key. Programs that can be joined independently MUST be modeled as separate sibling entries under the loyalty map, distinguished by reverse-domain naming (e.g., 'com.example.rewards' and 'com.example.rewards.card').

  Generated from: loyalty.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.LoyaltyCreateReq.MembershipReward
  alias Bazaar.Schemas.Common.LoyaltyCreateReq.MembershipTier

  @field_descriptions %{
    display_id:
      "A masked or partial version of the membership id for user recognition (e.g., '****5678'). MUST NOT be set if the membership has not been verified.",
    id: "Unique loyalty membership identifier.",
    name: "Business specific name of the loyalty membership/program.",
    provisional: "True if this membership requires additional verification.",
    rewards:
      "Reward types and earning forecasts associated with this membership. Each object encapsulates one type of reward.",
    tiers:
      "Active or display-safe tier context for this membership. Most programs are single-status (one entry); programs with parallel status dimensions (e.g., current and lifetime) populate one entry per active tier. Omitted when no tier context has been resolved."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:display_id, :string)
    field(:id, :string)
    field(:name, :string)
    field(:provisional, :boolean)
    embeds_many(:rewards, MembershipReward)
    embeds_many(:tiers, MembershipTier)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:display_id, :id, :name, :provisional])
    |> cast_embed(:rewards, required: false)
    |> cast_embed(:tiers, required: false)
    |> validate_required([:id, :name, :provisional])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
