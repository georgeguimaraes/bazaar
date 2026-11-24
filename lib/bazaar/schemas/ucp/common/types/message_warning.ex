defmodule Bazaar.Schemas.Common.Types.MessageWarning do
  @moduledoc """
  Message Warning

  Generated from: message_warning.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @content_type_values [:plain, :markdown]
  @type_values [:warning]
  @doc "Returns the description for a field, if available."
  def field_description(:code) do
    "Warning code identifying the type of warning. Standard codes are defined in capability specifications (see examples) and have standardized semantics; freeform codes are permitted."
  end

  def field_description(:content) do
    "Human-readable warning message that MUST be displayed."
  end

  def field_description(:content_type) do
    "Content format, default = plain."
  end

  def field_description(:image_url) do
    "URL to a required visual element (e.g., warning symbol, energy class label)."
  end

  def field_description(:path) do
    "RFC 9535 JSONPath to the component the message refers to (e.g., $.line_items[0])."
  end

  def field_description(:presentation) do
    "Rendering contract for this warning. 'notice' (default): platform MUST display, MAY dismiss. 'disclosure': platform MUST display in proximity to the path-referenced component, MUST NOT hide or auto-dismiss. See specification for full contract."
  end

  def field_description(:type) do
    "Message type discriminator."
  end

  def field_description(:url) do
    "Reference URL for more information (e.g., regulatory site, registry entry, policy page)."
  end

  def field_description(field) when is_atom(field) do
    nil
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
