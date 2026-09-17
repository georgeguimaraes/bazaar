defmodule Bazaar.Schemas.Shopping.Types.FulfillmentOptionCreateReq do
  @moduledoc """
  Fulfillment Option Create Request

  A fulfillment option within a group (e.g., Standard Shipping $5, Express $15). Extends the fulfillment option base with cost and timing.

  Generated from: fulfillment_option.create_req.json
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
