defmodule Bazaar.Schemas.Shopping.Order.PlatformSchema do
  @moduledoc """
  Platform Order Schema

  Platform's order capability configuration.

  Generated from: order.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    webhook_url: "URL where merchant sends order lifecycle events (webhooks)."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:webhook_url, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:webhook_url]) |> validate_required([:webhook_url])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
