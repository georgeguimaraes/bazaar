defmodule Bazaar.Schemas.UcpCompleteReq.Members do
  @moduledoc """
  Schema

  Members defined inside the reserved `ucp` protocol object. The object is open for forward compatibility: consumers MUST ignore unrecognized members. Only UCP core defines members, and every defined member MUST be safe to ignore.

  Generated from: ucp.complete_req.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @field_descriptions %{}
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    nil
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
