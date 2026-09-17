defmodule Bazaar.Schemas.Shopping.FulfillmentResp.CatalogFulfillmentMethod do
  @moduledoc """
  Catalog Fulfillment Method Response

  A fulfillment method on a catalog variant: how the variant can be fulfilled, and its availability.

  Generated from: fulfillment_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Description
  alias Bazaar.Schemas.Shopping.Types.Availability
  alias Bazaar.Schemas.Shopping.Types.FulfillmentOptionBaseResp

  @field_descriptions %{
    availability:
      "Availability of this variant via this method at the specified or inferred location.",
    description: "Short buyer-facing summary (e.g. 'Ships in 2–4 business days').",
    location:
      "Stable, opaque identifier for the Business Location resolved for this place-based fulfillment method. The Business recognizes the same ID when submitted as `selected_destination_id` for that method; recognition does not reserve inventory or guarantee eligibility, and current terms are revalidated.",
    options:
      "Representative fulfillment options for this method (e.g. Standard, Express). Without a destination or full cart, a Business SHOULD preview meaningful boundary options (e.g. cheapest, fastest); more specific options are negotiated in Checkout once line items and destination are known.",
    type:
      "Fulfillment method type. Well-known values: `shipping`, `pickup`. Businesses MAY use additional values."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:location, :string)
    field(:type, :string)
    embeds_one(:availability, Availability)
    embeds_one(:description, Description)
    embeds_many(:options, FulfillmentOptionBaseResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:location, :type])
    |> cast_embed(:availability, required: false)
    |> cast_embed(:description, required: false)
    |> cast_embed(:options, required: false)
    |> validate_required([:type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
