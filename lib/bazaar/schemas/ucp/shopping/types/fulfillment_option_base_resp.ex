defmodule Bazaar.Schemas.Shopping.Types.FulfillmentOptionBaseResp do
  @moduledoc """
  Fulfillment Option Base Response

  Common base for a fulfillment option: an addressable, renderable choice (e.g. Standard, Express). Catalog uses this base directly; checkout composes it with cost and timing.

  Generated from: fulfillment_option_base_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Description

  @field_descriptions %{
    description:
      "Supplementary context for the title (e.g. 'Arrives in 4 business days', 'Arrives Dec 12-15 via FedEx'). Directly renderable; MUST NOT repeat the title.",
    id: "Unique identifier for this fulfillment option.",
    title:
      "Short label that distinguishes this option from its siblings (e.g. 'Standard', 'Express Shipping', 'Curbside Pickup')."
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
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :title])
    |> cast_embed(:description, required: false)
    |> validate_required([:id, :title])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
