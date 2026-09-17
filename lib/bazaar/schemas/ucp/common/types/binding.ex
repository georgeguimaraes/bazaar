defmodule Bazaar.Schemas.Common.Types.Binding do
  @moduledoc """
  Binding

  Binds a credential or token to a specific capability resource. Prevents reuse across different resources.

  Generated from: binding.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    id:
      "Opaque identifier of the bound resource within the owning capability, for example a checkout identifier.",
    type:
      "The capability that owns the bound resource, for example dev.ucp.shopping.checkout. MUST be a capability name declared in the UCP namespace."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:type, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:id, :type]) |> validate_required([:type, :id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
