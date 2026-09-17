defmodule Bazaar.Schemas.Shopping.Types.InputCorrelation do
  @moduledoc """
  Input Correlation

  Maps a request identifier to the variant it resolved to, with match semantics.

  Generated from: input_correlation.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    id: "The identifier from the lookup request that resolved to this variant.",
    match:
      "How the request identifier resolved to this variant. Well-known values: `exact` (input directly identifies this variant, e.g., variant ID, SKU), `featured` (server selected this variant as representative, e.g., product ID resolved to best match). Businesses MAY implement and provide additional resolution strategies."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:match, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:id, :match]) |> validate_required([:id])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
