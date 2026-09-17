defmodule Bazaar.Schemas.Common.Types.LocationDistance do
  @moduledoc """
  Location Distance

  An explicit-center inclusive-radius predicate. The Business compares the unrounded shortest WGS 84 ellipsoidal geodesic distance in RFC 7035 distance unit (meters) from `center` to the Location's authoritative `geo`; a value less than or equal to `max` matches. Implementations MAY use any algorithm that produces the WGS 84 inverse-geodesic result at sufficient precision such that the match outcome agrees with this unrounded comparison. No context, signals, IP, or `serves` fallback, radius clamping, tolerance, or operand substitution is permitted.

  Generated from: location_distance.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Geo

  @field_descriptions %{
    center:
      "Explicit center of the radius. The Platform MUST supply it; the Business MUST NOT derive it from context, signals, an IP address, or `serves`.",
    max:
      "Inclusive maximum distance in RFC 7035 distance unit (meters). A Business unable to honor the supplied value MUST reject the request rather than clamp it or substitute another radius."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:max, :float)
    embeds_one(:center, Geo)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:max])
    |> cast_embed(:center, required: true)
    |> validate_required([:max])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
