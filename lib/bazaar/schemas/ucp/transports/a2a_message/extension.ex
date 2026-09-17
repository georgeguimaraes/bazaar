defmodule Bazaar.Schemas.Transports.A2aMessage.Extension do
  @moduledoc """
  Schema

  A2A Agent Card extension advertisement for UCP.

  Generated from: a2a_message.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    description: nil,
    params: "Extension parameters such as advertised UCP capabilities.",
    uri: "Extension URI. UCP uses its versioned reference URI."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:description, :string)
    field(:params, :map)
    field(:uri, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:description, :params, :uri]) |> validate_required([:uri])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
