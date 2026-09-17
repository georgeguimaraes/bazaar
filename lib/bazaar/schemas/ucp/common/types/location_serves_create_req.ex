defmodule Bazaar.Schemas.Common.Types.LocationServesCreateReq do
  @moduledoc """
  Location Serves Create Request

  A one-entry map whose key names the authoritative service-target representation. The Platform MUST supply exactly one target form. A Business that cannot evaluate a well-formed target, or receives an extension form that was not negotiated, MUST reject the request rather than ignore it, fall back, or broaden results. This dictionary-like representation map cannot host an ambient `ucp` member.

  Generated from: location_serves.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Geo
  alias Bazaar.Schemas.Common.Types.Locality

  @field_descriptions %{
    address: "Coarse locality of the service target.",
    point: "WGS 84 coordinates of the service target."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_one(:address, Locality)
    embeds_one(:point, Geo)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [])
    |> cast_embed(:address, required: false)
    |> cast_embed(:point, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
