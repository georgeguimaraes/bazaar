defmodule Bazaar.Schemas.Transports.A2aMessage.Message do
  @moduledoc """
  Schema

  A2A Message carrying natural-language or structured UCP data parts.

  Generated from: a2a_message.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Transports.A2aMessage.Part
  @kind_values [:message]
  @role_values [:user, :agent]
  @field_descriptions %{
    contextId: nil,
    kind: nil,
    messageId: nil,
    parts: nil,
    role: "Message sender role."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:contextId, :string)
    field(:messageId, :string)
    field(:kind, Ecto.Enum, values: @kind_values)
    field(:role, Ecto.Enum, values: @role_values)
    embeds_many(:parts, Part)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:contextId, :messageId, :kind, :role])
    |> cast_embed(:parts, required: true)
    |> validate_required([:role, :messageId, :kind, :contextId])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
