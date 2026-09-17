defmodule Bazaar.Schemas.Common.Types.ExceptionHourResp do
  @moduledoc """
  Exception Hour Response

  A date-specific operating interval or full closure. Its `valid_from`, `valid_through`, `opens`, and `closes` are local civil values interpreted in the containing Location's `timezone`. Date bounds are inclusive.

  Generated from: exception_hour_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    closes: "Closing time in 24-hour HH:MM format.",
    opens: "Opening time in 24-hour HH:MM format.",
    title:
      "A short human-readable heading naming the exception (for example, 'Thanksgiving'). Presentation metadata that does not affect schedule evaluation.",
    valid_from:
      "The first local civil date to which this exception applies, interpreted in the containing Location's `timezone`.",
    valid_through:
      "The last local civil date to which this exception applies, interpreted in the containing Location's `timezone`."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:closes, :string)
    field(:opens, :string)
    field(:title, :string)
    field(:valid_from, :date)
    field(:valid_through, :date)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:closes, :opens, :title, :valid_from, :valid_through])
    |> validate_required([:valid_from, :valid_through])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
