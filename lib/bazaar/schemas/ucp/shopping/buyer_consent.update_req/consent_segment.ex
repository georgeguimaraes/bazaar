defmodule Bazaar.Schemas.Shopping.BuyerConsentUpdateReq.ConsentSegment do
  @moduledoc """
  Schema

  A buyer's consent decision for a specific refinement of a parent purpose (e.g., email marketing under the marketing purpose). Overrides the parent's `granted` value for this scope. Segments do not nest further.

  Generated from: buyer_consent.update_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @source_values [:business, :platform]
  @field_descriptions %{
    granted:
      "Whether consent has been granted for this segment. Overrides the parent purpose's `granted` value for this specific scope.",
    source:
      "Identifies the party that asserted the current `granted` value for this segment. `business` means the value reflects the business's default policy; `platform` means the value reflects an explicit buyer decision captured by the platform."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:granted, :boolean)
    field(:source, Ecto.Enum, values: @source_values)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:granted, :source]) |> validate_required([:granted, :source])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
