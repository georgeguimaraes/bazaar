defmodule Bazaar.Schemas.Common.LoyaltyCompleteReq.MembershipReward do
  @moduledoc """
  Schema

  Quantifiable reward type and optional earning forecast for the current transaction.

  Generated from: loyalty.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.LoyaltyCompleteReq.EarningForecast
  alias Bazaar.Schemas.Common.LoyaltyCompleteReq.RewardCurrency

  @field_descriptions %{
    currency:
      "A unit of value that customers can accumulate through various commercial activities.",
    earning_forecast: "Preview of rewards to be earned from the current transaction."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_one(:currency, RewardCurrency)
    embeds_one(:earning_forecast, EarningForecast)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:currency, required: true)
    |> cast_embed(:earning_forecast, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
