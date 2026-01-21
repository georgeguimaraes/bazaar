defmodule Bazaar.Schemas.Shopping.Types.Binding do
  @moduledoc """
  Binding
  
  Binds a token to a specific checkout session and participant. Prevents token reuse across different checkouts or participants.
  
  Generated from: binding.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.Types.PaymentIdentity

  @field_descriptions %{
    checkout_id: "The checkout session identifier this token is bound to.",
    identity:
      "The participant this token is bound to. Required when acting on behalf of another participant (e.g., agent tokenizing for merchant). Omit when the authenticated caller is the binding target."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:checkout_id, :string)
    embeds_one(:identity, PaymentIdentity)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:checkout_id])
    |> cast_embed(:identity, required: false)
    |> validate_required([:checkout_id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
