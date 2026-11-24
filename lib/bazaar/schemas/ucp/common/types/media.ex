defmodule Bazaar.Schemas.Common.Types.Media do
  @moduledoc """
  Media

  Media item (image, video, etc.).

  Generated from: media.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:alt_text) do
    "Accessibility text describing the media."
  end

  def field_description(:height) do
    "Height in pixels (for images/video)."
  end

  def field_description(:type) do
    "Media type. Well-known values: `image`, `video`, `model_3d`."
  end

  def field_description(:url) do
    "URL to the media resource."
  end

  def field_description(:width) do
    "Width in pixels (for images/video)."
  end

  def field_description(field) when is_atom(field) do
    nil
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
