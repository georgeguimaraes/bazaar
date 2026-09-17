defmodule Bazaar.Schemas.Common.Types.ActionsResp.Instance do
  @moduledoc """
  Schema

  Common fields for one outstanding Action instance are id and optional config. The extension declaring the Action type defines type-specific processing data under config. Additional properties are permitted for forward compatibility.

  Generated from: actions_resp.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    config: "Configuration defined by the extension that declares this Action type.",
    id: "Identifier for this Action instance."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
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
