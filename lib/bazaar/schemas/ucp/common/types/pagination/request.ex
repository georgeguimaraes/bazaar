defmodule Bazaar.Schemas.Common.Types.Pagination.Request do
  @moduledoc """
  Schema

  Pagination parameters for requests.

  Generated from: pagination.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    cursor: "Opaque cursor from previous response.",
    limit:
      "Requested page size, not a guaranteed result count. When omitted, the Business MUST apply a default page size. A default of 10 is RECOMMENDED, but the Business MAY choose another value. The Business MAY return fewer results than the requested or default page size, including when enforcing its maximum page size. A Platform MUST NOT assume that the response count equals either value."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:cursor, :string)
    field(:limit, :integer)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:cursor, :limit])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
