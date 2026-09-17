defmodule Bazaar.Schemas.Common.Types.TotalsResp do
  @moduledoc """
  Totals Response

  Pricing breakdown provided by the business. MUST contain exactly one subtotal and one total entry. Detail types (tax, fee, discount, fulfillment) may appear multiple times for itemization. Platforms MUST render all entries in order using display_text and amount.

  Generated from: totals_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @field_descriptions %{}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    nil
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
