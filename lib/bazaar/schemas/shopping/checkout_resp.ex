defmodule Bazaar.Schemas.Shopping.CheckoutResp do
  @moduledoc """
  Checkout Response
  
  Base checkout schema. Extensions compose onto this using allOf.
  
  Generated from: checkout_resp.json
  """
  import Ecto.Changeset

  @status_values [
    :incomplete,
    :requires_escalation,
    :ready_for_complete,
    :complete_in_progress,
    :completed,
    :canceled
  ]
  @status_type Ecto.ParameterizedType.init(Ecto.Enum, values: @status_values)
  @fields [
    %{
      name: :buyer,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.Buyer.fields(), with: &Function.identity/1),
      description: "Representation of the buyer."
    },
    %{
      name: :continue_url,
      type: :string,
      description:
        "URL for checkout handoff and session recovery. MUST be provided when status is requires_escalation. See specification for format and availability requirements."
    },
    %{name: :currency, type: :string, description: "ISO 4217 currency code."},
    %{
      name: :expires_at,
      type: :utc_datetime,
      description: "RFC 3339 expiry timestamp. Default TTL is 6 hours from creation if not sent."
    },
    %{name: :id, type: :string, description: "Unique identifier of the checkout session."},
    %{
      name: :line_items,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.LineItemResp.fields(),
          with: &Function.identity/1
        ),
      description: "List of line items being checked out."
    },
    %{
      name: :links,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.Link.fields(), with: &Function.identity/1),
      description:
        "Links to be displayed by the platform (Privacy Policy, TOS). Mandatory for legal compliance."
    },
    %{
      name: :messages,
      type: {:array, :map},
      description: "List of messages with error and info about the checkout session state."
    },
    %{
      name: :order,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.OrderConfirmation.fields(),
          with: &Function.identity/1
        ),
      description: "Details about an order created for this checkout session."
    },
    %{
      name: :payment,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.PaymentResp.fields(), with: &Function.identity/1)
    },
    %{
      name: :status,
      type: @status_type,
      description:
        "Checkout state indicating the current phase and required action. See Checkout Status lifecycle documentation for state transition details."
    },
    %{
      name: :totals,
      type:
        Schemecto.many(Bazaar.Schemas.Shopping.Types.TotalResp.fields(),
          with: &Function.identity/1
        ),
      description: "Different cart totals."
    },
    %{
      name: :ucp,
      type:
        Schemecto.one(Bazaar.Schemas.Ucp.ResponseCheckout.fields(), with: &Function.identity/1)
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
    |> validate_required([:ucp, :id, :line_items, :status, :currency, :totals, :links, :payment])
  end
end