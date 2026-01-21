defmodule Bazaar.Schemas.Shopping.CheckoutCreateReq do
  @moduledoc """
  Checkout Create Request

  Composite schema for creating a new checkout session.
  Validates the incoming request before processing.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Bazaar.Schemas.Shopping.Types.Buyer
  alias Bazaar.Schemas.Shopping.Types.LineItemCreateReq

  @primary_key false
  embedded_schema do
    field(:currency, :string)
    embeds_one(:buyer, Buyer)
    embeds_many(:line_items, LineItemCreateReq)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:currency])
    |> cast_embed(:buyer)
    |> cast_embed(:line_items, required: true)
    |> validate_required([:currency])
    |> validate_line_items_not_empty()
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}), do: changeset(params)

  defp validate_line_items_not_empty(changeset) do
    case get_field(changeset, :line_items) do
      nil -> changeset
      [] -> add_error(changeset, :line_items, "must have at least one item")
      _ -> changeset
    end
  end
end
