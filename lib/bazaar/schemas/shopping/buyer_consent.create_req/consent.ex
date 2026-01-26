defmodule Bazaar.Schemas.Shopping.BuyerConsentCreateReq.Consent do
  @moduledoc """
  Schema

  User consent states for data processing

  Generated from: buyer_consent.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    analytics: "Consent for analytics and performance tracking.",
    marketing: "Consent for marketing communications.",
    preferences: "Consent for storing user preferences.",
    sale_of_data: "Consent for selling data to third parties (CCPA)."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:analytics, :boolean)
    field(:marketing, :boolean)
    field(:preferences, :boolean)
    field(:sale_of_data, :boolean)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:analytics, :marketing, :preferences, :sale_of_data])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
