defmodule Bazaar.Schemas.UcpResp.Members do
  @moduledoc """
  Schema

  Members defined inside the reserved `ucp` protocol object. The object is open for forward compatibility: consumers MUST ignore unrecognized members. Only UCP core defines members, and every defined member MUST be safe to ignore.

  Generated from: ucp_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.RequestConstraints
  @doc "Returns the description for a field, if available."
  def field_description(:map_order) do
    "Preferred key order for map-valued fields in the scope annotated by the containing `ucp` member. Each property names a target map, and its array lists target keys in preferred order. Lists may be partial and are not allowlists."
  end

  def field_description(:request_constraints) do
    nil
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:map_order, :map)
    embeds_one(:request_constraints, RequestConstraints)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:map_order]) |> cast_embed(:request_constraints, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
