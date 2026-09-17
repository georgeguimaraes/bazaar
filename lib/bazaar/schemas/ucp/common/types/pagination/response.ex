defmodule Bazaar.Schemas.Common.Types.Pagination.Response do
  @moduledoc """
  Schema

  Pagination information in responses.

  Generated from: pagination.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    cursor:
      "Cursor to fetch the next page of results. MUST be present when has_next_page is true.",
    has_next_page: "Whether more results are available.",
    total_count: "Total number of matching items, if available."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:cursor, :string)
    field(:has_next_page, :boolean)
    field(:total_count, :integer)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:cursor, :has_next_page, :total_count])
    |> validate_required([:has_next_page])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
