defmodule Bazaar.Schemas.Shopping.Types.TotalResp do
  @moduledoc """
  Total Response
  
  Generated from: total_resp.json
  """
  import Ecto.Changeset
  @type_values [:items_discount, :subtotal, :discount, :fulfillment, :tax, :fee, :total]
  @type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @type_values)
  @fields [
    %{
      name: :amount,
      type: :integer,
      description:
        "If type == total, sums subtotal - discount + fulfillment + tax + fee. Should be >= 0. Amount in minor (cents) currency units."
    },
    %{
      name: :display_text,
      type: :string,
      description:
        "Text to display against the amount. Should reflect appropriate method (e.g., 'Shipping', 'Delivery')."
    },
    %{name: :type, type: @type_type, description: "Type of total categorization."}
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params) |> validate_required([:type, :amount])
  end
end