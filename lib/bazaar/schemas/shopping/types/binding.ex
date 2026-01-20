defmodule Bazaar.Schemas.Shopping.Types.Binding do
  @moduledoc """
  Binding
  
  Binds a token to a specific checkout session and participant. Prevents token reuse across different checkouts or participants.
  
  Generated from: binding.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :checkout_id,
      type: :string,
      description: "The checkout session identifier this token is bound to."
    },
    %{
      name: :identity,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.PaymentIdentity.fields(),
          with: &Function.identity/1
        ),
      description:
        "The participant this token is bound to. Required when acting on behalf of another participant (e.g., agent tokenizing for merchant). Omit when the authenticated caller is the binding target."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:checkout_id])
  end
end