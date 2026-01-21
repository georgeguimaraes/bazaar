defmodule Bazaar.Schemas.Shopping.CheckoutUpdateReq do
  @moduledoc """
  Checkout Update Request

  Composite schema for updating an existing checkout session.
  All fields are optional for partial updates.
  """

  alias Bazaar.Schemas.Shopping.Types.LineItemUpdateReq

  @fields [
    %{
      name: :line_items,
      type: Schemecto.many(LineItemUpdateReq.fields(), with: &Function.identity/1),
      description: "List of line items to update in the checkout."
    },
    %{
      name: :buyer,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.Buyer.fields(), with: &Function.identity/1),
      description: "Updated buyer information."
    },
    %{
      name: :payment,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.PaymentHandlerUpdateReq.fields(),
          with: &Function.identity/1
        ),
      description: "Payment information update."
    },
    %{
      name: :fulfillment,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.FulfillmentReq.fields(),
          with: &Function.identity/1
        ),
      description: "Fulfillment information update."
    }
  ]

  @doc "Returns the field definitions for this schema."
  def fields, do: @fields

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
  end
end
