defmodule Bazaar.Schemas.Common.Types.MessageWarning do
  @moduledoc """
  Message Warning

  Generated from: message_warning.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @content_type_values [:plain, :markdown]
  @type_values [:warning]
  @field_descriptions %{
    code:
      "Warning code identifying the type of warning. Standard codes are defined in capability specifications (see examples) and have standardized semantics; freeform codes are permitted.",
    content: "Human-readable warning message that MUST be displayed.",
    content_type: "Content format, default = plain.",
    image_url: "URL to a required visual element (e.g., warning symbol, energy class label).",
    path: "RFC 9535 JSONPath to the component the message refers to (e.g., $.line_items[0]).",
    presentation:
      "Rendering contract for this warning. 'notice' (default): platform MUST display, MAY dismiss. 'disclosure': platform MUST display in proximity to the path-referenced component, MUST NOT hide or auto-dismiss. See specification for full contract.",
    type: "Message type discriminator.",
    url:
      "Reference URL for more information (e.g., regulatory site, registry entry, policy page)."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:code, :string)
    field(:content, :string)
    field(:image_url, :string)
    field(:path, :string)
    field(:presentation, :string)
    field(:url, :string)
    field(:content_type, Ecto.Enum, values: @content_type_values)
    field(:type, Ecto.Enum, values: @type_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :code,
      :content,
      :image_url,
      :path,
      :presentation,
      :url,
      :content_type,
      :type
    ])
    |> validate_required([:type, :code, :content])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
