defmodule Bazaar.Schemas.Shopping.Types.LocationDestinationResp do
  @moduledoc """
  Business Location Destination Response

  A business location fulfillment destination. Business-authored and response-only: the Platform selects a location via `selected_destination_id` rather than writing destinations.

  Generated from: location_destination_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PostalAddress
  @type_values [:business_location]
  @doc "Returns the description for a field, if available."
  def field_description(:address) do
    "Physical address of the location."
  end

  def field_description(:id) do
    "Stable, opaque, Business-scoped Location identifier."
  end

  def field_description(:name) do
    "Buyer-facing, Business-owned display name."
  end

  def field_description(:type) do
    "Destination type discriminator. Response-only."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:name, :string)
    field(:type, Ecto.Enum, values: @type_values)
    embeds_one(:address, PostalAddress)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :name, :type])
    |> cast_embed(:address, required: false)
    |> validate_required([:id, :name, :type])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
