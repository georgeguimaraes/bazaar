defmodule Bazaar.Schemas.Shopping.Types.Link do
  @moduledoc """
  Link

  Generated from: link.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    title:
      "Optional display text for the link. When provided, use this instead of generating from type.",
    type:
      "Type of link. Well-known values: `privacy_policy`, `terms_of_service`, `refund_policy`, `shipping_policy`, `faq`. Consumers SHOULD handle unknown values gracefully by displaying them using the `title` field or omitting the link.",
    url: "The actual URL pointing to the content to be displayed."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:title, :string)
    field(:type, :string)
    field(:url, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:title, :type, :url]) |> validate_required([:type, :url])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
