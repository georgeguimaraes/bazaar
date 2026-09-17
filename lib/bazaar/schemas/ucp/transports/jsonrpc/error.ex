defmodule Bazaar.Schemas.Transports.Jsonrpc.Error do
  @moduledoc """
  Schema

  JSON-RPC transport-level error object. UCP business outcomes use result payloads with UCP messages instead of this object.

  Generated from: jsonrpc.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    code:
      "JSON-RPC error code. Standard codes are negative integers; UCP bindings reserve business errors for UCP messages.",
    data: "Optional machine-readable transport error details.",
    message: "Short transport-level error description."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:code, :integer)
    field(:data, :map)
    field(:message, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:code, :data, :message]) |> validate_required([:code, :message])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
