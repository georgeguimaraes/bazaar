defmodule Bazaar.Schemas.Shopping.Types.OptionValue do
  @moduledoc """
  Option Value

  A selectable value for a product option.

  Generated from: option_value.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:id) do
    "Optional server-assigned identifier for this option value. When present in a selected_option, the server SHOULD use it for matching instead of label."
  end

  def field_description(:label) do
    "Display text for this option value (e.g., 'Small', 'Blue')."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:label, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:id, :label]) |> validate_required([:label])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
