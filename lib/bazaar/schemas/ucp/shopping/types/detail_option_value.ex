defmodule Bazaar.Schemas.Shopping.Types.DetailOptionValue do
  @moduledoc """
  Detail Option Value

  An option value with availability signals relative to the current selections. Used in get_product responses where selected context exists.

  Generated from: detail_option_value.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    available:
      "Whether a variant matching this value and the current option selections is purchasable.",
    exists:
      "Whether a variant matching this value and the current option selections exists in the catalog.",
    id:
      "Optional server-assigned identifier for this option value. When present in a selected_option, the server SHOULD use it for matching instead of label.",
    label: "Display text for this option value (e.g., 'Small', 'Blue')."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:available, :boolean)
    field(:exists, :boolean)
    field(:id, :string)
    field(:label, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:available, :exists, :id, :label]) |> validate_required([:label])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
