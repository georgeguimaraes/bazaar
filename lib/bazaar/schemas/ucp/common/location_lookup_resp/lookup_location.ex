defmodule Bazaar.Schemas.Common.LocationLookupResp.LookupLocation do
  @moduledoc """
  Location Response

  Location with required correlation metadata for lookup responses.

  Generated from: location_lookup_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.DailyHourResp
  alias Bazaar.Schemas.Common.Types.ExceptionHourResp
  alias Bazaar.Schemas.Common.Types.Geo
  alias Bazaar.Schemas.Common.Types.PostalAddress

  @field_descriptions %{
    address: "Physical address of the location.",
    amenities:
      "Static features, services, or capabilities of the Location, keyed by reverse-domain amenity identifier. Each value provides a buyer-facing description; the key alone defines amenity identity and filter matching.",
    exception_hours:
      "Date-specific operating-hour exceptions, including full closures, whose date and time values use this Location's canonical local civil-time frame.",
    geo: "Geographic coordinates for the location.",
    hours:
      "Regular weekly operating hours whose day and time values use this Location's canonical local civil-time frame. Multiple entries for the same day support split shifts. An omitted day has no regular interval beginning that day; an interval beginning on the preceding day can carry into it. Omission of the entire `hours` property means the regular schedule is unknown.",
    id: "Stable, opaque, Business-scoped Location identifier.",
    inputs:
      "Which request identifiers resolved to this Location. Each entry preserves one identifier exactly as supplied in the request.",
    name: "Buyer-facing, Business-owned display name.",
    timezone:
      "The Business-owned IANA Time Zone Database identifier (e.g., 'America/New_York') defining this Location's canonical local civil-time frame for all returned schedule day, time, and date fields. The Business does not vary this canonical framing by the requesting Platform's or Buyer's timezone. Required when hours or exception_hours is present."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:amenities, :map)
    field(:id, :string)
    field(:inputs, {:array, :map})
    field(:name, :string)
    field(:timezone, :string)
    embeds_one(:address, PostalAddress)
    embeds_many(:exception_hours, ExceptionHourResp)
    embeds_one(:geo, Geo)
    embeds_many(:hours, DailyHourResp)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:amenities, :id, :inputs, :name, :timezone])
    |> cast_embed(:address, required: false)
    |> cast_embed(:exception_hours, required: false)
    |> cast_embed(:geo, required: false)
    |> cast_embed(:hours, required: false)
    |> validate_required([:id, :name, :inputs])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
