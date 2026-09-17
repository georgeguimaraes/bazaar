defmodule Bazaar.Schemas.Shopping.DiscountUpdateReq.AppliedDiscount do
  @moduledoc """
  Schema

  A discount that was successfully applied.

  Generated from: discount.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Shopping.DiscountUpdateReq.Allocation
  @method_values [:each, :across]
  @field_descriptions %{
    allocations:
      "Breakdown of where this discount was allocated. Sum of allocation amounts equals total amount.",
    amount: "Total discount amount in ISO 4217 minor units.",
    automatic: "True if applied automatically by merchant rules (no code required).",
    code: "The discount code. Omitted for automatic discounts.",
    eligibility:
      "The eligibility claim accepted by the Business for this discount. Corresponds to a value from context.eligibility. Omitted for code-based and non-eligibility automatic discounts.",
    method:
      "Allocation method. 'each' = applied independently per item. 'across' = split proportionally by value.",
    priority: "Stacking order for discount calculation. Lower numbers applied first (1 = first).",
    provisional: "True if this discount requires additional verification.",
    title: "Human-readable discount name (e.g., 'Summer Sale 20% Off')."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amount, :integer)
    field(:automatic, :boolean)
    field(:code, :string)
    field(:eligibility, :string)
    field(:priority, :integer)
    field(:provisional, :boolean)
    field(:title, :string)
    field(:method, Ecto.Enum, values: @method_values)
    embeds_many(:allocations, Allocation)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :amount,
      :automatic,
      :code,
      :eligibility,
      :priority,
      :provisional,
      :title,
      :method
    ])
    |> cast_embed(:allocations, required: false)
    |> validate_required([:title, :amount])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
