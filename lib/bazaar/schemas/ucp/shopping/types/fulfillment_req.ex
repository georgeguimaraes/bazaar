defmodule Bazaar.Schemas.Shopping.Types.FulfillmentReq do
  @moduledoc """
  Fulfillment Request

  Container for fulfillment methods and availability.

  Generated from: fulfillment_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.FulfillmentMethodCreateReq
  @field_descriptions %{methods: "Fulfillment methods for cart items."}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_many(:methods, FulfillmentMethodCreateReq)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, []) |> cast_embed(:methods, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
