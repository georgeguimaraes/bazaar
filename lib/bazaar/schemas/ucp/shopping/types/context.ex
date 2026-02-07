defmodule Bazaar.Schemas.Shopping.Types.Context do
  @moduledoc """
  Context

  Provisional buyer signals for relevance and localization: product availability, pricing, currency, tax, shipping, payment methods, and eligibility (e.g., student or affiliation discounts). Businesses SHOULD use these values when authoritative data (e.g., address) is absent, and MAY ignore unsupported values without returning errors. Context can be disclosed progressively—coarse signals early, finer resolution as the session progresses. Higher-resolution data (shipping address, billing address) supersedes context. Platforms SHOULD progressively enhance context throughout the buyer journey.

  Generated from: context.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    address_country:
      "The country. Recommended to be in 2-letter ISO 3166-1 alpha-2 format, for example \"US\". For backward compatibility, a 3-letter ISO 3166-1 alpha-3 country code such as \"SGP\" or a full country name such as \"Singapore\" can also be used. Optional hint for market context (currency, availability, pricing)—higher-resolution data (e.g., shipping address) supersedes this value.",
    address_region:
      "The region in which the locality is, and which is in the country. For example, California or another appropriate first-level Administrative division. Optional hint for progressive localization—higher-resolution data (e.g., shipping address) supersedes this value.",
    postal_code:
      "The postal code. For example, 94043. Optional hint for regional refinement—higher-resolution data (e.g., shipping address) supersedes this value."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
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
