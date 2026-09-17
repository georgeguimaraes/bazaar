defmodule Bazaar.Schemas.Common.Types.Media do
  @moduledoc """
  Media

  Media item (image, video, etc.).

  Generated from: media.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    alt_text: "Accessibility text describing the media.",
    height: "Height in pixels (for images/video).",
    type: "Media type. Well-known values: `image`, `video`, `model_3d`.",
    url: "URL to the media resource.",
    width: "Width in pixels (for images/video)."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:alt_text, :string)
    field(:height, :integer)
    field(:type, :string)
    field(:url, :string)
    field(:width, :integer)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:alt_text, :height, :type, :url, :width])
    |> validate_required([:type, :url])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
