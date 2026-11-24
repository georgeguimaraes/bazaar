defmodule Bazaar.Schemas.Common.Types.Locality do
  @moduledoc """
  Locality

  A coarse geographic location — country, region, and postal code. A lightweight alternative to a full postal address.

  Generated from: locality.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:address_country) do
    "The country, as a 2-letter ISO 3166-1 alpha-2 code (e.g. \"US\"). A 3-letter alpha-3 code or full country name MAY also be used."
  end

  def field_description(:address_region) do
    "The first-level administrative region within the country (e.g. a state or province such as California)."
  end

  def field_description(:postal_code) do
    "The postal code (e.g. \"94043\")."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:address_country, :string)
    field(:address_region, :string)
    field(:postal_code, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:address_country, :address_region, :postal_code])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
