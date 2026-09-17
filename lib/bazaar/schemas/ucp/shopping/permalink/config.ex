defmodule Bazaar.Schemas.Shopping.Permalink.Config do
  @moduledoc """
  Schema

  Business browser endpoint configuration for shopping permalinks.

  Generated from: permalink.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    endpoint:
      "Absolute HTTPS browser endpoint with a non-empty authority and without userinfo, query, fragment, whitespace, backslashes, or trailing slash. Optional compact item path and query parameters are appended to this endpoint."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:endpoint, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:endpoint]) |> validate_required([:endpoint])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
