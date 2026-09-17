defmodule Bazaar.Schemas.Common.PaymentTermsResp.Payment do
  @moduledoc """
  Payment with Terms Response

  Payment object extended with selectable payment terms.

  Generated from: payment_terms_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PaymentTerm

  @field_descriptions %{
    selected_term_id:
      "ID of the selected payment term. MUST match one `terms[].id` from the latest Checkout response. Present in a response whenever `terms` is, and absent when it is not: the Checkout total is the selected term's total, so a list of terms without a selection would show an amount that matches no stated term. Where the Buyer has made no choice, the Business selects a default. Omitted on create requests because term IDs are checkout-scoped and no terms exist yet, and on complete requests because the term is already agreed by then. Selecting a term is an Update Checkout mutation: the Business response is authoritative for all derived state.",
    terms:
      "Payment terms the Buyer can choose from. An unselected term's amounts are indicative; the selected term's schedule amounts sum to the checkout total."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:selected_term_id, :string)
    embeds_many(:terms, PaymentTerm)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:selected_term_id]) |> cast_embed(:terms, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
