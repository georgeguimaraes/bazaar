defmodule Bazaar.Schemas.Shopping.CheckoutCreateReq do
  @moduledoc """
  Checkout Create Request

  Composite schema for creating a new checkout session.
  Validates the incoming request before processing.
  """
  import Ecto.Changeset

  alias Bazaar.Schemas.Shopping.Types.LineItemCreateReq

  @fields [
    %{
      name: :line_items,
      type: Schemecto.many(LineItemCreateReq.fields(), with: &Function.identity/1),
      description: "List of line items to add to the checkout."
    },
    %{
      name: :currency,
      type: :string,
      description: "ISO 4217 currency code for the checkout."
    },
    %{
      name: :buyer,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.Buyer.fields(), with: &Function.identity/1),
      description: "Optional buyer information."
    }
  ]

  @doc "Returns the field definitions for this schema."
  def fields, do: @fields

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
    |> validate_required([:line_items, :currency])
    |> validate_line_items_not_empty()
  end

  defp validate_line_items_not_empty(changeset) do
    case get_field(changeset, :line_items) do
      nil -> changeset
      [] -> add_error(changeset, :line_items, "must have at least one item")
      _ -> changeset
    end
  end
end
