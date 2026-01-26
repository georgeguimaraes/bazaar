defmodule Bazaar.Schemas.Transports.EmbeddedConfig do
  @moduledoc """
  Embedded Transport Config

  Per-checkout configuration for embedded transport binding. Allows businesses to vary ECP availability and delegations based on cart contents, agent authorization, or policy.

  Generated from: embedded_config.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    delegate:
      "Delegations the business allows. At service-level, declares available delegations. In checkout responses, confirms accepted delegations for this session."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:delegate, {:array, :map})
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:delegate])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
