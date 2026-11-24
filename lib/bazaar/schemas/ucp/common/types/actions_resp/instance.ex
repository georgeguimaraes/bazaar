defmodule Bazaar.Schemas.Common.Types.ActionsResp.Instance do
  @moduledoc """
  Schema

  Common fields for one outstanding Action instance are id and optional config. The extension declaring the Action type defines type-specific processing data under config. Additional properties are permitted for forward compatibility.

  Generated from: actions_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:config) do
    "Configuration defined by the extension that declares this Action type."
  end

  def field_description(:id) do
    "Identifier for this Action instance."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:config, :map)
    field(:id, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:config, :id]) |> validate_required([:id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
