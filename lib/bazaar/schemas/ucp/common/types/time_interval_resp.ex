defmodule Bazaar.Schemas.Common.Types.TimeIntervalResp do
  @moduledoc """
  Time Interval Response

  Reusable opening and closing time fields for a containing schedule schema. Containing schemas determine whether the `opens` and `closes` pair is required; this fragment's standalone `{}` is not an interval.

  Generated from: time_interval_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    closes: "Closing time in 24-hour HH:MM format.",
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
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:closes, :opens])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
