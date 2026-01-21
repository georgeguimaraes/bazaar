defmodule Bazaar.Schemas.Shopping.Types.OrderConfirmation do
  @moduledoc """
  Order Confirmation
  
  Order details available at the time of checkout completion.
  
  Generated from: order_confirmation.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    id: "Unique order identifier.",
    permalink_url: "Permalink to access the order on merchant site."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:permalink_url, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:id, :permalink_url]) |> validate_required([:id, :permalink_url])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
