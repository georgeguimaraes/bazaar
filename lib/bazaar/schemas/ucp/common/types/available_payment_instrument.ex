defmodule Bazaar.Schemas.Common.Types.AvailablePaymentInstrument do
  @moduledoc """
  Available Payment Instrument

  An instrument type available from a payment handler with optional constraints.

  Generated from: available_payment_instrument.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.ConstraintExpression

  @field_descriptions %{
    constraints:
      "A Constraint Expression describing the instrument this entry makes available. Keys in `properties` name members of the `constraint_target` declared by the instrument schema for this `type`. Requirements on submitted request data belong in `ucp.request_constraints` instead.",
    type:
      "The instrument type identifier (e.g., 'card', 'gift_card'). References an instrument schema's type constant."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:type, :string)
    embeds_one(:constraints, ConstraintExpression)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type])
    |> cast_embed(:constraints, required: false)
    |> validate_required([:type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
