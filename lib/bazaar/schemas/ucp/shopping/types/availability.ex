defmodule Bazaar.Schemas.Shopping.Types.Availability do
  @moduledoc """
  Availability

  Availability of an item: whether it can be obtained, and a qualifying status.

  Generated from: availability.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:available) do
    "Whether this can be obtained. See status for fulfillment details."
  end

  def field_description(:status) do
    "Qualifies available with fulfillment state. Well-known values: `in_stock`, `backorder`, `preorder`, `out_of_stock`, `discontinued`."
  end

  def field_description(field) when is_atom(field) do
    nil
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
