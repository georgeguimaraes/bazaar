defmodule Bazaar.Schemas.Shopping.Types.Expectation do
  @moduledoc """
  Expectation
  
  Buyer-facing fulfillment expectation representing logical groupings of items (e.g., 'package'). Can be split, merged, or adjusted post-order to set buyer expectations for when/how items arrive.
  
  Generated from: expectation.json
  """
  import Ecto.Changeset
  @method_type_values [:shipping, :pickup, :digital]
  @method_type_type Ecto.ParameterizedType.init(Ecto.Enum, values: @method_type_values)
  @fields [
    %{
      name: :description,
      type: :string,
      description: "Human-readable delivery description (e.g., 'Arrives in 5-8 business days')."
    },
    %{
      name: :destination,
      type:
        Schemecto.one(Bazaar.Schemas.Shopping.Types.PostalAddress.fields(),
          with: &Function.identity/1
        ),
      description: "Delivery destination address."
    },
    %{
      name: :fulfillable_on,
      type: :string,
      description:
        "When this expectation can be fulfilled: 'now' or ISO 8601 timestamp for future date (backorder, pre-order)."
    },
    %{name: :id, type: :string, description: "Expectation identifier."},
    %{
      name: :line_items,
      type: {:array, :map},
      description: "Which line items and quantities are in this expectation."
    },
    %{
      name: :method_type,
      type: @method_type_type,
      description: "Delivery method type (shipping, pickup, digital)."
    }
  ]
  @doc "Returns the field definitions for this schema."
  def fields do
    @fields
  end

  @doc "Creates a new changeset from params."
  def new(params \\ %{}) do
    Schemecto.new(@fields, params)
    |> validate_required([:id, :line_items, :method_type, :destination])
  end
end