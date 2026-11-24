defmodule Bazaar.Schemas.Common.Types.Description do
  @moduledoc """
  Description

  Description content in one or more formats. At least one format must be provided.

  Generated from: description.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:html) do
    "HTML-formatted content. Security: Platforms MUST sanitize before rendering—strip scripts, event handlers, and untrusted elements. Treat all rich text as untrusted input."
  end

  def field_description(:markdown) do
    "Markdown-formatted content."
  end

  def field_description(:plain) do
    "Plain text content."
  end

  def field_description(field) when is_atom(field) do
    nil
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
