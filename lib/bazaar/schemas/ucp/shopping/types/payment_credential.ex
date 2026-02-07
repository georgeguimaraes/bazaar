defmodule Bazaar.Schemas.Shopping.Types.PaymentCredential do
  @moduledoc """
  Payment Credential

  The base definition for any payment credential. Handlers define specific credential types.

  Generated from: payment_credential.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    type:
      "The credential type discriminator. Specific schemas will constrain this to a constant value."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:type, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:type]) |> validate_required([:type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
