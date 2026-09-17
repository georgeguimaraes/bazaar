defmodule Bazaar.Schemas.Common.Types.DailyHourResp do
  @moduledoc """
  Daily Hour Response

  A regular weekly operating interval. Its `day`, `opens`, and `closes` are recurring local civil values interpreted in the containing Location's `timezone`. Multiple entries for the same day support split shifts.

  Generated from: daily_hour_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @day_values [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
  @field_descriptions %{
    closes: "Closing time in 24-hour HH:MM format.",
    day:
      "A stable UCP day-of-week identifier for the day on which this recurring local civil-time interval begins in the containing Location's `timezone`. It is not localized display text.",
    opens: "Opening time in 24-hour HH:MM format."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:closes, :string)
    field(:opens, :string)
    field(:day, Ecto.Enum, values: @day_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:closes, :opens, :day]) |> validate_required([:day, :opens, :closes])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
