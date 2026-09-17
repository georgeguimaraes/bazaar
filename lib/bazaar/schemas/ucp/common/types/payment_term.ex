defmodule Bazaar.Schemas.Common.Types.PaymentTerm do
  @moduledoc """
  Payment Term

  A way of paying for the checkout: one or more payment schedules that together cover its total.

  Generated from: payment_term.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Description
  alias Bazaar.Schemas.Common.Types.PaymentSchedule

  @field_descriptions %{
    description:
      "Supplementary context for the title (e.g. 'Save 5% by paying today'). Directly renderable; MUST NOT repeat the title.",
    id:
      "Unique identifier for this payment term within the checkout. Referenced by `payment.selected_term_id`.",
    schedules:
      "Payment schedules that settle this checkout under this term, in the order they come due.",
    title:
      "Short label that distinguishes this term from its siblings (e.g. 'Pay now', 'Pay in 4', 'Deposit + balance at check-in')."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:title, :string)
    embeds_one(:description, Description)
    embeds_many(:schedules, PaymentSchedule)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :title])
    |> cast_embed(:description, required: false)
    |> cast_embed(:schedules, required: true)
    |> validate_required([:id, :title])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
