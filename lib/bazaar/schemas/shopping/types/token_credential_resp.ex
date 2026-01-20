defmodule Bazaar.Schemas.Shopping.Types.TokenCredentialResp do
  @moduledoc """
  Token Credential Response
  
  Base token credential schema. Concrete payment handlers may extend this schema with additional fields and define their own constraints.
  
  Generated from: token_credential_resp.json
  """
  import Ecto.Changeset

  @fields [
    %{
      name: :type,
      type: :string,
      description: "The specific type of token produced by the handler (e.g., 'stripe_token')."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:type])
  end
end