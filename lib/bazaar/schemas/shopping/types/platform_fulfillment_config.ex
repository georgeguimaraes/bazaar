defmodule Bazaar.Schemas.Shopping.Types.PlatformFulfillmentConfig do
  @moduledoc """
  Platform Fulfillment Config
  
  Platform's fulfillment configuration.
  
  Generated from: platform_fulfillment_config.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @field_descriptions %{supports_multi_group: "Enables multiple groups per method."}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:supports_multi_group, :boolean)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:supports_multi_group])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
