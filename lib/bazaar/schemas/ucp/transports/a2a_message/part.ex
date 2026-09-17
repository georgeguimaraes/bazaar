defmodule Bazaar.Schemas.Transports.A2aMessage.Part do
  @moduledoc """
  Schema

  A2A message part. UCP examples use text parts for natural language and data parts for structured UCP payloads.

  Generated from: a2a_message.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    data: "Structured data payload. UCP reserves a2a.ucp.* keys for UCP payloads.",
    kind: nil,
    text: nil,
    type: nil
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:data, :map)
    field(:kind, :string)
    field(:text, :string)
    field(:type, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:data, :kind, :text, :type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
