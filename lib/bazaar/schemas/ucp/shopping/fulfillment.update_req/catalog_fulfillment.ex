defmodule Bazaar.Schemas.Shopping.FulfillmentUpdateReq.CatalogFulfillment do
  @moduledoc """
  Catalog Fulfillment Update Request

  How a catalog variant can be fulfilled. Mirrors checkout `fulfillment`.

  Generated from: fulfillment.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.FulfillmentUpdateReq.CatalogFulfillmentMethod
  @field_descriptions %{methods: "Fulfillment methods for this variant."}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_many(:methods, CatalogFulfillmentMethod)
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
