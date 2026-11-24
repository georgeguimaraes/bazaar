defmodule Bazaar.Schemas.Common.Types.LocationSummaryResp do
  @moduledoc """
  Location Summary Response

  A summary of a physical business location.

  Generated from: location_summary_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.PostalAddress
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

  def field_description(field) when is_atom(field) do
    nil
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
