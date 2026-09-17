defmodule Bazaar.Schemas.Common.Types.PaymentSchedule do
  @moduledoc """
  Payment Schedule

  A single payment that settles part or all of the checkout under a payment term. Timing is stated in buyer-facing text; `type` and `due_at` are supplementary machine-readable signals derived from it.

  Generated from: payment_schedule.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Description

  @field_descriptions %{
    amount:
      "The amount charged when this payment is taken, inclusive of tax and every other charge, in the Checkout currency's minor units (ISO 4217). A schedule states an amount rather than a totals breakdown: the purchase is priced once at the Checkout, and a schedule moves part or all of that price. Where the selected term changes what the purchase costs, that difference appears in `checkout.totals`, not here.",
    description:
      "Complete buyer-facing statement of when and how this payment is due. Businesses MUST make this field sufficient on its own: a Platform that recognizes no `type` value and reads no other field MUST be able to present this schedule correctly. Platforms MAY use `type` and `due_at` for enhanced presentation, but MUST NOT present derived timing that contradicts this field.",
    due_at:
      "Absolute RFC 3339 date-time when this payment is due, when the Business can determine one at checkout. Supplementary to `description`, never a replacement for it. Omitted when the due date depends on a future event (e.g. 'due on delivery'); the timing is then stated in `description` alone.",
    id:
      "Identifier for this payment schedule, unique within its payment term. Businesses SHOULD keep it stable across responses while the schedule remains the same payment.",
    type:
      "Timing class, drawn from an open vocabulary. `immediate` is the only value with defined meaning: the payment is due when the checkout is completed. Any other value means the payment is not due at completion, and `description` states when it is due. Whether a due payment is authorized, captured, or settled at that moment is payment-handler behavior and outside this extension. Businesses MAY use additional values (e.g. `deferred`, `on_shipment`); Platforms MUST treat unrecognized values as not due at completion."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amount, :integer)
    field(:due_at, :utc_datetime)
    field(:id, :string)
    field(:type, :string)
    embeds_one(:description, Description)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:amount, :due_at, :id, :type])
    |> cast_embed(:description, required: true)
    |> validate_required([:id, :type, :amount])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
