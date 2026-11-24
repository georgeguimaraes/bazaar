defmodule Bazaar.Schemas.UcpCreateReq.Requires do
  @moduledoc """
  Schema

  Version requirements for extension schemas. Declares minimum (and optionally maximum) protocol and capability versions needed for correct operation.

  Generated from: ucp.create_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.UcpCreateReq.VersionConstraint
  @doc "Returns the description for a field, if available."
  def field_description(:capabilities) do
    "Required capability versions, keyed by capability name. Keys must be a subset of the extension's $defs keys."
  end

  def field_description(:protocol) do
    "Required range for the selected `ucp.version`."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:capabilities, :map)
    embeds_one(:protocol, VersionConstraint)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:capabilities]) |> cast_embed(:protocol, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
