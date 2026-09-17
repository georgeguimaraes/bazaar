defmodule Bazaar.Schemas.Shopping.Types.FulfillmentOptionResp do
  @moduledoc """
  Fulfillment Option Response

  A fulfillment option within a group (e.g., Standard Shipping $5, Express $15). Extends the fulfillment option base with cost and timing.

  Generated from: fulfillment_option_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Description
  alias Bazaar.Schemas.Common.Types.TotalResp

  @field_descriptions %{
    carrier: "Carrier name (for shipping).",
    description:
      "Supplementary context for the title (e.g. 'Arrives in 4 business days', 'Arrives Dec 12-15 via FedEx'). Directly renderable; MUST NOT repeat the title.",
    earliest_fulfillment_time: "Earliest fulfillment date.",
    id: "Unique identifier for this fulfillment option.",
    latest_fulfillment_time: "Latest fulfillment date.",
    title:
      "Short label that distinguishes this option from its siblings (e.g. 'Standard', 'Express Shipping', 'Curbside Pickup').",
    totals: "Fulfillment option totals breakdown."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:carrier, :string)
    field(:earliest_fulfillment_time, :utc_datetime)
    field(:id, :string)
    field(:latest_fulfillment_time, :utc_datetime)
    field(:title, :string)
    embeds_one(:description, Description)
    embeds_many(:totals, TotalResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:carrier, :earliest_fulfillment_time, :id, :latest_fulfillment_time, :title])
    |> cast_embed(:description, required: false)
    |> cast_embed(:totals, required: true)
    |> validate_required([:id, :title])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
