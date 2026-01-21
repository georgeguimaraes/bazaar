defmodule Bazaar.Schemas.Shopping.Types.TokenCredentialCreateReq do
  @moduledoc """
  Token Credential Create Request
  
  Base token credential schema. Concrete payment handlers may extend this schema with additional fields and define their own constraints.
  
  Generated from: token_credential.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    token: "The token value.",
    type: "The specific type of token produced by the handler (e.g., 'stripe_token')."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:token, :string)
    field(:type, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:token, :type]) |> validate_required([:type, :token])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
