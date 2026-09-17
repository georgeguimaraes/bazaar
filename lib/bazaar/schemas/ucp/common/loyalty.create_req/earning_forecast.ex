defmodule Bazaar.Schemas.Common.LoyaltyCreateReq.EarningForecast do
  @moduledoc """
  Schema

  Preview of rewards to be earned from the current transaction.

  Generated from: loyalty.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.LoyaltyCreateReq.EarningBreakdown

  @field_descriptions %{
    amount: "Total rewards to be earned if the transaction completes.",
    breakdown: "List of breakdown of earning contributing to the total."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amount, :integer)
    embeds_many(:breakdown, EarningBreakdown)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:amount])
    |> cast_embed(:breakdown, required: false)
    |> validate_required([:amount])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
