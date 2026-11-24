defmodule Bazaar.Schemas.Shopping.Types.SelectedOption do
  @moduledoc """
  Selected Option

  A specific option selection on a variant (e.g., Size: Large).

  Generated from: selected_option.json
  """
  use Ecto.Schema
  import Ecto.Changeset
  @doc "Returns the description for a field, if available."
  def field_description(:id) do
    "Optional option value identifier from option_value.id. When present, the server SHOULD use it for matching; name and label remain required for display."
  end

  def field_description(:label) do
    "Selected option label (e.g., 'Large')."
  end

  def field_description(:name) do
    "Option name (e.g., 'Size')."
  end

  def field_description(field) when is_atom(field) do
    nil
  end

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:label, :string)
    field(:name, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:id, :label, :name]) |> validate_required([:name, :label])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
