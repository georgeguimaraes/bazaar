defmodule Bazaar.Schemas.Shopping.Types.Buyer do
  @moduledoc """
  Buyer

  Generated from: buyer.json
  """
  use Ecto.Schema
  import Ecto.Changeset

  @field_descriptions %{
    email: "Email of the buyer.",
    first_name: "First name of the buyer.",
    last_name: "Last name of the buyer.",
    phone_number: "E.164 standard."
  }
  @doc "Returns the description for a field, if available."
  def field_description(field) when is_atom(field) do
    Map.get(@field_descriptions, field)
  end

  @primary_key false
  embedded_schema do
    field(:email, :string)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:phone_number, :string)
  end

  @doc "Creates a changeset for validating and casting params."
  def changeset(struct \\ %__MODULE__{}, params) do
    struct |> cast(params, [:email, :first_name, :last_name, :phone_number])
  end

  (
    @doc "Creates a new changeset from params."
    def new(params \\ %{}) do
      changeset(params)
    end
  )
end
