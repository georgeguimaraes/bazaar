defmodule Bazaar.Schemas.Common.Types.CardPaymentInstrument.ConstraintTarget do
  @moduledoc """
  Card Constraint Target

  The object an available card instrument's `constraints` describes. It declares the constrainable members and their types and is never carried in a payload.

  Generated from: card_payment_instrument.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @field_descriptions %{brand: "Card scheme. Derived from the account number, not submitted."}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:brand, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:brand])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
