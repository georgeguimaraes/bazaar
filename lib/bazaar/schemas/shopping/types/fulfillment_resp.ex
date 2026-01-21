defmodule Bazaar.Schemas.Shopping.Types.FulfillmentResp do
  @moduledoc """
  Fulfillment Response
  
  Container for fulfillment methods and availability.
  
  Generated from: fulfillment_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.FulfillmentAvailableMethodResp
  alias Bazaar.Schemas.Shopping.Types.FulfillmentMethodResp

  @field_descriptions %{
    available_methods: "Inventory availability hints.",
    methods: "Fulfillment methods for cart items."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_many(:available_methods, FulfillmentAvailableMethodResp)
    embeds_many(:methods, FulfillmentMethodResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:available_methods, required: false)
    |> cast_embed(:methods, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
