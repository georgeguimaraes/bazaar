defmodule Bazaar.Schemas.Shopping.Ap2MandateResp.Ap2WithMerchantAuthorization do
  @moduledoc """
  Schema

  AP2 extension data including merchant authorization.

  Generated from: ap2_mandate_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    merchant_authorization: "Merchant's signature proving checkout terms are authentic."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:merchant_authorization, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:merchant_authorization])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
