defmodule Bazaar.Schemas.Shopping.Types.PaymentIdentity do
  @moduledoc """
  Payment Identity
  
  Identity of a participant for token binding. The access_token uniquely identifies the participant who tokens should be bound to.
  
  Generated from: payment_identity.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :access_token,
      type: :string,
      description:
        "Unique identifier for this participant, obtained during onboarding with the tokenizer."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:access_token])
  end
end