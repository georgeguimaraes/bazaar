defmodule Bazaar.Schemas.Shopping.Types.MessageInfo do
  @moduledoc """
  Message Info

  Generated from: message_info.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @content_type_values [:plain, :markdown]
  @type_values [:info]
  @field_descriptions %{
    code: "Info code for programmatic handling.",
    content: "Human-readable message.",
    content_type: "Content format, default = plain.",
    path: "RFC 9535 JSONPath to the component the message refers to.",
    type: "Message type discriminator."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:code, :string)
    field(:content, :string)
    field(:path, :string)
    field(:content_type, Ecto.Enum, values: @content_type_values)
    field(:type, Ecto.Enum, values: @type_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:code, :content, :path, :content_type, :type])
    |> validate_required([:type, :content])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
