defmodule Bazaar.Schemas.Transports.McpToolCall.Arguments do
  @moduledoc """
  Schema

  MCP tool arguments. UCP reserves meta for transport metadata; operation payload fields such as checkout, cart, order id, or catalog inputs are operation-specific.

  Generated from: mcp_tool_call.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Transports.McpToolCall.Meta
  @field_descriptions %{meta: "UCP request metadata passed through MCP params.arguments.meta."}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_one(:meta, Meta)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, []) |> cast_embed(:meta, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
