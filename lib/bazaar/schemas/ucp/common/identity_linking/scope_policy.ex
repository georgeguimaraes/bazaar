defmodule Bazaar.Schemas.Common.IdentityLinking.ScopePolicy do
  @moduledoc """
  Scope Policy

  Per-scope policy and metadata — auth constraints (e.g. min_acr, max_token_age), declarative metadata (e.g. claims produced, consent descriptions), or any other scope-specific configuration. An empty object means user authentication is required with no additional policy. Open for non-breaking extension.

  Generated from: identity_linking.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Common.Types.Description

  @field_descriptions %{
    description:
      "Optional human-readable description of the scope that platforms can use to present and explain context (requirement and value) to the user."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    embeds_one(:description, Description)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, []) |> cast_embed(:description, required: false)
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
