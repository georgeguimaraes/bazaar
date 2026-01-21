defmodule Bazaar.Schemas.Ucp.ResponseOrder do
  @moduledoc """
  UCP Order Response
  
  UCP metadata for order responses. No payment handlers needed post-purchase.
  
  Generated from: ucp.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Bazaar.Schemas.Capability.Response

  @field_descriptions %{
    capabilities: "Active capabilities for this response.",
    version: "UCP protocol version in YYYY-MM-DD format."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:version, :string)
    embeds_many(:capabilities, Response)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:version])
    |> cast_embed(:capabilities, required: true)
    |> validate_required([:version])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
