defmodule Bazaar.Schemas.Shopping.Types.FulfillmentOptionBaseCreateReq do
  @moduledoc """
  Fulfillment Option Base Create Request

  Common base for a fulfillment option: an addressable, renderable choice (e.g. Standard, Express). Catalog uses this base directly; checkout composes it with cost and timing.

  Generated from: fulfillment_option_base.create_req.json
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
