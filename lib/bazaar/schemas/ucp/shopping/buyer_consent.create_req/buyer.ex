defmodule Bazaar.Schemas.Shopping.BuyerConsentCreateReq.Buyer do
  @moduledoc """
  Buyer with Consent Create Request

  Buyer object extended with per-purpose consent.

  Generated from: buyer_consent.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:consent) do
    "Per-purpose consent decisions and business-advertised consent options."
  end

  def field_description(:email) do
    "Email of the buyer."
  end

  def field_description(:first_name) do
    "First name of the buyer."
  end

  def field_description(:last_name) do
    "Last name of the buyer."
  end

  def field_description(:phone_number) do
    "E.164 standard."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:consent, :map)
    field(:email, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:phone_number, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:consent, :email, :first_name, :last_name, :phone_number])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
