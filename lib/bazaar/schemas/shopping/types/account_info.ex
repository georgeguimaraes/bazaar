defmodule Bazaar.Schemas.Shopping.Types.AccountInfo do
  @moduledoc """
  Payment Account Info
  
  Non-sensitive backend identifiers for linking.
  
  Generated from: account_info.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    payment_account_reference:
      "EMVCo PAR. A unique identifier linking a payment card to a specific account, enabling tracking across tokens (Apple Pay, physical card, etc)."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:payment_account_reference, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:payment_account_reference])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end