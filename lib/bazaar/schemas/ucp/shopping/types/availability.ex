defmodule Bazaar.Schemas.Shopping.Types.Availability do
  @moduledoc """
  Availability

  Availability of an item: whether it can be obtained, and a qualifying status.

  Generated from: availability.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    available: "Whether this can be obtained. See status for fulfillment details.",
    status:
      "Qualifies available with fulfillment state. Well-known values: `in_stock`, `backorder`, `preorder`, `out_of_stock`, `discontinued`."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:available, :boolean)
    field(:status, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:available, :status])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
