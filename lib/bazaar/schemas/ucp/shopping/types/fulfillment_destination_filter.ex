defmodule Bazaar.Schemas.Shopping.Types.FulfillmentDestinationFilter do
  @moduledoc """
  Fulfillment Destination Filter

  A specific destination, named by value or by reference: a coarse locality (`address_country` / `address_region` / `postal_code`), or a `location` id. Platforms SHOULD provide one or the other, not both; if both are present, a business SHOULD use the more specific — typically `location`.

  Generated from: fulfillment_destination_filter.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    address_country:
      "The country, as a 2-letter ISO 3166-1 alpha-2 code (e.g. \"US\"). A 3-letter alpha-3 code or full country name MAY also be used.",
    address_region:
      "The first-level administrative region within the country (e.g. a state or province such as California).",
    location: "A reference to the destination (e.g. store, pickup location, saved address).",
    postal_code: "The postal code (e.g. \"94043\")."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:address_country, :string)
    field(:address_region, :string)
    field(:location, :string)
    field(:postal_code, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:address_country, :address_region, :location, :postal_code])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
