defmodule Bazaar.Schemas.Shopping.Types.FulfillmentCreateReq do
  @moduledoc """
  Fulfillment Create Request

  Container for fulfillment methods and availability.

  Generated from: fulfillment.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.FulfillmentMethodCreateReq
  @doc "Returns the description for a field, if available."
  def field_description(:methods) do
    "Fulfillment methods for cart items."
  end

  def field_description(field) when is_atom(field) do
    nil
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
