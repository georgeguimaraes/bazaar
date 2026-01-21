defmodule Bazaar.Schemas.Shopping.Types.AccountInfo do
  @moduledoc """
  Payment Account Info
  
  Non-sensitive backend identifiers for linking.
  
  Generated from: account_info.json
  """
  @fields [
    %{
      name: :payment_account_reference,
      type: :string,
      description:
        "EMVCo PAR. A unique identifier linking a payment card to a specific account, enabling tracking across tokens (Apple Pay, physical card, etc)."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
  end
end