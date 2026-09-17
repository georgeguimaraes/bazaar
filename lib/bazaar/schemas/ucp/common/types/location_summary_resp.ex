defmodule Bazaar.Schemas.Common.Types.LocationSummaryResp do
  @moduledoc """
  Location Summary Response

  A summary of a physical business location.

  Generated from: location_summary_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PostalAddress

  @field_descriptions %{
    address: "Physical address of the location.",
    id: "Stable, opaque, Business-scoped Location identifier.",
    name: "Buyer-facing, Business-owned display name."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:name, :string)
    embeds_one(:address, PostalAddress)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :name])
    |> cast_embed(:address, required: false)
    |> validate_required([:id, :name])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
