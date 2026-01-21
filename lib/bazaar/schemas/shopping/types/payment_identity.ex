defmodule Bazaar.Schemas.Shopping.Types.PaymentIdentity do
  @moduledoc """
  Payment Identity
  
  Identity of a participant for token binding. The access_token uniquely identifies the participant who tokens should be bound to.
  
  Generated from: payment_identity.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    access_token:
      "Unique identifier for this participant, obtained during onboarding with the tokenizer."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:access_token, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:access_token]) |> validate_required([:access_token])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end