defmodule Bazaar.Schemas.Transports.A2aMessage.AgentCard do
  @moduledoc """
  Schema

  A2A Agent Card fragment advertising UCP support through extensions.

  Generated from: a2a_message.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Transports.A2aMessage.Extension
  @field_descriptions %{extensions: nil}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_many(:extensions, Extension)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, []) |> cast_embed(:extensions, required: true)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
