defmodule Bazaar.Schemas.Common.Types.LocationResp.Amenity do
  @moduledoc """
  Amenity Response

  Buyer-facing presentation metadata for one amenity identifier. The containing map key, not this metadata, defines amenity identity and filter matching.

  Generated from: location_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    description:
      "Short, plain-text, buyer-facing label or phrase for the amenity, suitable for direct use in a compact list (e.g., 'Curbside pickup'). The Business SHOULD localize it for the request when possible. This content does not participate in amenity identity or filter matching."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:description, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:description]) |> validate_required([:description])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
