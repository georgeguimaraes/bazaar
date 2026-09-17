defmodule Bazaar.Schemas.Shopping.Types.FulfillmentDestinationCompleteReq do
  @moduledoc """
  Fulfillment Destination Complete Request

  A destination for fulfillment.

  Generated from: fulfillment_destination.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    id: "Fulfillment destination identifier.",
    type:
      "Destination contract discriminator. Required in Business responses and optional in Platform requests. Well-known values: `shipping_address`, `business_location`. The enclosing method contract defines request defaults and which fields the Platform may write; negotiated extensions define additional values."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:type, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:id, :type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
