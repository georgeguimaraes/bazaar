defmodule Bazaar.Schemas.Shopping.Types.ShippingDestinationResp do
  @moduledoc """
  Shipping Destination Response

  Shipping destination.

  Generated from: shipping_destination_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    address_country:
      "The country. Recommended to be in 2-letter ISO 3166-1 alpha-2 format, for example \"US\". For backward compatibility, a 3-letter ISO 3166-1 alpha-3 country code such as \"SGP\" or a full country name such as \"Singapore\" can also be used.",
    address_locality:
      "The locality in which the street address is, and which is in the region. For example, Mountain View.",
    address_region:
      "The region in which the locality is, and which is in the country. Required for applicable countries (i.e. state in US, province in CA). For example, California or another appropriate first-level Administrative division.",
    extended_address:
      "An address extension such as an apartment number, C/O or alternative name.",
    first_name: "Optional. First name of the contact associated with the address.",
    full_name:
      "Optional. Full name of the contact associated with the address (if first_name or last_name fields are present they take precedence).",
    id: "ID specific to this shipping destination.",
    last_name: "Optional. Last name of the contact associated with the address.",
    phone_number: "Optional. Phone number of the contact associated with the address.",
    postal_code: "The postal code. For example, 94043.",
    street_address: "The street address."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:address_country, :string)
    field(:address_locality, :string)
    field(:address_region, :string)
    field(:extended_address, :string)
    field(:first_name, :string)
    field(:full_name, :string)
    field(:id, :string)
    field(:last_name, :string)
    field(:phone_number, :string)
    field(:postal_code, :string)
    field(:street_address, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :address_country,
      :address_locality,
      :address_region,
      :extended_address,
      :first_name,
      :full_name,
      :id,
      :last_name,
      :phone_number,
      :postal_code,
      :street_address
    ])
    |> validate_required([:id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
