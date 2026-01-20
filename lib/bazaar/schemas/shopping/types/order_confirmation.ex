defmodule Bazaar.Schemas.Shopping.Types.OrderConfirmation do
  @moduledoc """
  Order Confirmation
  
  Order details available at the time of checkout completion.
  
  Generated from: order_confirmation.json
  """
  import Ecto.Changeset

  @fields [
    %{name: :id, type: :string, description: "Unique order identifier."},
    %{
      name: :permalink_url,
      type: :string,
      description: "Permalink to access the order on merchant site."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:id, :permalink_url])
  end
end