defmodule Bazaar.Schemas.Common.Types.Description do
  @moduledoc """
  Description

  Description content in one or more formats. At least one format must be provided.

  Generated from: description.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    html:
      "HTML-formatted content. Security: Platforms MUST sanitize before rendering—strip scripts, event handlers, and untrusted elements. Treat all rich text as untrusted input.",
    markdown: "Markdown-formatted content.",
    plain: "Plain text content."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:html, :string)
    field(:markdown, :string)
    field(:plain, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:html, :markdown, :plain])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
