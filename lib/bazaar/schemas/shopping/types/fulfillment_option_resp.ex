defmodule Bazaar.Schemas.Shopping.Types.FulfillmentOptionResp do
  @moduledoc """
  Fulfillment Option Response
  
  A fulfillment option within a group (e.g., Standard Shipping $5, Express $15).
  
  Generated from: fulfillment_option_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.TotalResp

  @field_descriptions %{
    carrier: "Carrier name (for shipping).",
    description: "Complete context for buyer decision (e.g., 'Arrives Dec 12-15 via FedEx').",
    earliest_fulfillment_time: "Earliest fulfillment date.",
    id: "Unique fulfillment option identifier.",
    latest_fulfillment_time: "Latest fulfillment date.",
    title: "Short label (e.g., 'Express Shipping', 'Curbside Pickup').",
    totals: "Fulfillment option totals breakdown."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:carrier, :string)
    field(:description, :string)
    field(:earliest_fulfillment_time, :utc_datetime)
    field(:id, :string)
    field(:latest_fulfillment_time, :utc_datetime)
    field(:title, :string)
    embeds_many(:totals, TotalResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :carrier,
      :description,
      :earliest_fulfillment_time,
      :id,
      :latest_fulfillment_time,
      :title
    ])
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