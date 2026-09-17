defmodule Bazaar.Schemas.Common.Types.ErrorResponse do
  @moduledoc """
  Error Response

  Generic error response when business logic prevents resource creation or failed to retrieve resource. Used when no valid resource can be established.

  Generated from: error_response.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.UcpResp.Error

  @field_descriptions %{
    continue_url: "URL for buyer handoff or session recovery.",
    messages: "Array of messages describing why the operation failed.",
    ucp: "UCP protocol metadata. Status MUST be 'error' for error response."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:continue_url, :string)
    field(:messages, {:array, :map})
    embeds_one(:ucp, Error)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:continue_url, :messages])
    |> cast_embed(:ucp, required: true)
    |> validate_required([:messages])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
