defmodule Bazaar.Schemas.Common.Types.ExceptionHourCompleteReq do
  @moduledoc """
  Exception Hour Complete Request

  A date-specific operating interval or full closure. Its `valid_from`, `valid_through`, `opens`, and `closes` are local civil values interpreted in the containing Location's `timezone`. Date bounds are inclusive.

  Generated from: exception_hour.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @field_descriptions %{}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    nil
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
