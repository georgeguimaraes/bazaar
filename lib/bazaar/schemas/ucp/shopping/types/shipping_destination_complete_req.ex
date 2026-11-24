defmodule Bazaar.Schemas.Shopping.Types.ShippingDestinationCompleteReq do
  @moduledoc """
  Shipping Destination Complete Request

  Shipping destination.

  Generated from: shipping_destination.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @type_values [:shipping_address]
  @doc "Returns the description for a field, if available."
  def field_description(:address_country) do
    "The country. Recommended to be in 2-letter ISO 3166-1 alpha-2 format, for example \"US\". For backward compatibility, a 3-letter ISO 3166-1 alpha-3 country code such as \"SGP\" or a full country name such as \"Singapore\" can also be used."
  end

  def field_description(:address_locality) do
    "The locality in which the street address is, and which is in the region. For example, Mountain View."
  end

  def field_description(:address_region) do
    "The region in which the locality is, and which is in the country. Required for applicable countries (i.e. state in US, province in CA). For example, California or another appropriate first-level Administrative division."
  end

  def field_description(:extended_address) do
    "An address extension such as an apartment number, C/O or alternative name."
  end

  def field_description(:first_name) do
    "Optional. First name of the contact associated with the address."
  end

  def field_description(:id) do
    "ID specific to this shipping destination."
  end

  def field_description(:last_name) do
    "Optional. Last name of the contact associated with the address."
  end

  def field_description(:phone_number) do
    "Optional. Phone number of the contact associated with the address."
  end

  def field_description(:postal_code) do
    "The postal code. For example, 94043."
  end

  def field_description(:street_address) do
    "The street address."
  end

  def field_description(:type) do
    "Destination type discriminator."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:address_country, :string)
    field(:address_locality, :string)
    field(:address_region, :string)
    field(:extended_address, :string)
    field(:first_name, :string)
    field(:id, :string)
    field(:last_name, :string)
    field(:phone_number, :string)
    field(:postal_code, :string)
    field(:street_address, :string)
    field(:type, Ecto.Enum, values: @type_values)
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
      :id,
      :last_name,
      :phone_number,
      :postal_code,
      :street_address,
      :type
    ])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
