defmodule Bazaar.Schemas.Transports.McpToolCall.ContentPart do
  @moduledoc """
  Schema

  MCP content part returned for clients that do not consume structuredContent.

  Generated from: mcp_tool_call.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @field_descriptions %{text: nil, type: nil}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:text, :string)
    field(:type, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:text, :type]) |> validate_required([:type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
